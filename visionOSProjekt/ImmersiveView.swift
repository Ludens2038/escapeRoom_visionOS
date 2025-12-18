import SwiftUI
import RealityKit
import RealityKitContent
import Spatial
import UIKit
import ARKit

struct ImmersiveView: View {
    @State private var subscriptions: [EventSubscription] = []
    @StateObject private var handTracker = HandJointsTracker()

    private let movableNames: Set<String> = ["CubeRed", "CubeYellow", "CubeBlue"]
    private let fixedNames: Set<String>   = ["CubeSocketLeft", "CubeSocketRight"]

    // Escape-Status
    @State private var bluePlaced: Bool = false
    @State private var yellowPlaced: Bool = false

    // Persistent head anchor and text entity references
    @State private var headAnchor: AnchorEntity? = nil
    @State private var escapeTextEntity: ModelEntity? = nil

    private let placementThreshold: Float = 0.03 // 3cm Toleranz

    var body: some View {
        RealityView { content in
            
            // 1) Joint-Entities anlegen (enablePhysics = true => Hände können dynamic bodies schieben)
            handTracker.setupEntities(enablePhysics: true)
            content.add(handTracker.rootEntity)

            // 2) Hand Tracking starten
            Task { await handTracker.start() }
            
            if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(scene)

                // Create and add a persistent head anchor once
                let head = AnchorEntity(.head)
                content.add(head)
                headAnchor = head

                // Fixe Würfel: static + Collision
                for name in fixedNames {
                    if let fixed = scene.findEntity(named: name) {
                        ensureCollision(on: fixed)
                        fixed.components.set(PhysicsBodyComponent(mode: .static))
                    }
                }

                // Helper: Prüfen ob Cube nahe an einem Socket sitzt
                @MainActor
                func isPlaced(_ cubeName: String) -> Bool {
                    guard let cube = scene.findEntity(named: cubeName) else { return false }
                    let cubePos = cube.position(relativeTo: nil)

                    for socketName in fixedNames {
                        guard let socket = scene.findEntity(named: socketName) else { continue }
                        let socketPos = socket.position(relativeTo: nil)
                        if simd_distance(cubePos, socketPos) <= placementThreshold {
                            return true
                        }
                    }
                    return false
                }

                // Helper: State aktualisieren + "ecaped" Text ein-/ausblenden
                @MainActor
                func refreshPlacementAndEscape() async {
                    bluePlaced = isPlaced("CubeBlue")
                    yellowPlaced = isPlaced("CubeYellow")

                    let bothPlaced = bluePlaced && yellowPlaced

                    guard let headAnchor else { return }

                    if bothPlaced {
                        // Create text entity if needed and attach to headAnchor
                        if escapeTextEntity == nil {
                            try? await Task.sleep(nanoseconds: 500_000_000)
                            let mesh = MeshResource.generateText(
                                "ESCAPED",
                                extrusionDepth: 0.01,
                                font: .systemFont(ofSize: 0.12, weight: .bold),
                                containerFrame: .zero,
                                alignment: .center,
                                lineBreakMode: .byWordWrapping
                            )
                            let material = SimpleMaterial(color: .white, isMetallic: false)
                            let textEntity = ModelEntity(mesh: mesh, materials: [material])

                            // 1m vor Head (negative Z)
                            textEntity.position = SIMD3<Float>(-0.291, 0, -1.0)

                            headAnchor.addChild(textEntity)
                            escapeTextEntity = textEntity
                        }
                    } else {
                        // Remove text entity if present
                        escapeTextEntity?.removeFromParent()
                        escapeTextEntity = nil
                    }
                }

                // Bewegliche Würfel
                for name in movableNames {
                    guard let cube = scene.findEntity(named: name) else { continue }

                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    cube.components.set(manipulation)

                    ensureCollision(on: cube)

                    if cube.components[PhysicsBodyComponent.self] == nil {
                        cube.components.set(PhysicsBodyComponent(mode: .dynamic))
                    }

                    // WillBegin -> kinematic
                    subscriptions.append(
                        content.subscribe(to: ManipulationEvents.WillBegin.self) { event in
                            guard movableNames.contains(event.entity.name) else { return }
                            Task { @MainActor in
                                if var body = event.entity.components[PhysicsBodyComponent.self] {
                                    body.mode = .kinematic
                                    event.entity.components.set(body)
                                }
                            }
                        }
                    )

                    // WillRelease -> dynamic + placement check
                    subscriptions.append(
                        content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                            guard movableNames.contains(event.entity.name) else { return }
                            Task { @MainActor in
                                if var body = event.entity.components[PhysicsBodyComponent.self] {
                                    body.mode = .dynamic
                                    event.entity.components.set(body)
                                }
                                await refreshPlacementAndEscape()
                            }
                        }
                    )

                    // Kollision -> Snap + placement check
                    subscriptions.append(
                        content.subscribe(to: CollisionEvents.Began.self, on: cube) { collision in
                            let a = collision.entityA
                            let b = collision.entityB

                            @MainActor
                            func snap(_ moving: Entity, to target: Entity) {
                                if var body = moving.components[PhysicsBodyComponent.self] {
                                    body.mode = .kinematic
                                    moving.components.set(body)
                                }

                                let targetPos = target.position(relativeTo: nil)
                                let targetOri = target.orientation(relativeTo: nil)

                                moving.setPosition(targetPos, relativeTo: nil)
                                moving.setOrientation(targetOri, relativeTo: nil)

                                if var motion = moving.components[PhysicsMotionComponent.self] {
                                    motion.linearVelocity = .zero
                                    motion.angularVelocity = .zero
                                    moving.components.set(motion)
                                }
                            }

                            Task { @MainActor in
                                if movableNames.contains(a.name), fixedNames.contains(b.name) {
                                    snap(a, to: b)
                                } else if movableNames.contains(b.name), fixedNames.contains(a.name) {
                                    snap(b, to: a)
                                }
                                await refreshPlacementAndEscape()
                            }
                        }
                    )
                }

                // Initialer Check (falls Szene schon korrekt startet)
                Task { @MainActor in
                    await refreshPlacementAndEscape()
                }
            }
        }
    }

    private func ensureCollision(on entity: Entity) {
        guard entity.components[CollisionComponent.self] == nil else { return }

        let bounds = entity.visualBounds(relativeTo: entity)
        let e = bounds.extents
        let size = SIMD3<Float>(max(e.x, 0.1), max(e.y, 0.1), max(e.z, 0.1))

        entity.components.set(CollisionComponent(shapes: [.generateBox(size: size)]))
    }
}
