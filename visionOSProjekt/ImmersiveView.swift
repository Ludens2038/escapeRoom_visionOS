import SwiftUI
import RealityKit
import RealityKitContent
import Spatial

struct ImmersiveView: View {
    @State private var subscriptions: [EventSubscription] = []

    private let movableNames: Set<String> = ["CubeRed", "CubeYellow", "CubeBlue"]
    private let fixedNames: Set<String>   = ["CubeSocketLeft", "CubeSocketRight"]

    var body: some View {
        RealityView { content in
            if let scene = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(scene)

                // 1) Fixe Würfel: static + Collision sicherstellen
                for name in fixedNames {
                    if let fixed = scene.findEntity(named: name) {
                        ensureCollision(on: fixed)
                        fixed.components.set(PhysicsBodyComponent(mode: .static))
                    }
                }

                // 2) Bewegliche Würfel: Manipulation + dynamic + Collision + Collision-Subscribe
                for name in movableNames {
                    guard let cube = scene.findEntity(named: name) else { continue }

                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    cube.components.set(manipulation)

                    ensureCollision(on: cube)

                    if cube.components[PhysicsBodyComponent.self] == nil {
                        cube.components.set(PhysicsBodyComponent(mode: .dynamic))
                    }

                    // Manipulation -> kinematic während Griff, danach wieder dynamic
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

                    subscriptions.append(
                        content.subscribe(to: ManipulationEvents.WillRelease.self) { event in
                            guard movableNames.contains(event.entity.name) else { return }
                            Task { @MainActor in
                                if var body = event.entity.components[PhysicsBodyComponent.self] {
                                    body.mode = .dynamic
                                    event.entity.components.set(body)
                                }
                            }
                        }
                    )

                    // Kollision -> Snap auf Position des fixen Würfels
                    subscriptions.append(
                        content.subscribe(to: CollisionEvents.Began.self, on: cube) { collision in
                            let a = collision.entityA
                            let b = collision.entityB

                            // helper: "moving" nimmt Pose von "target" an
                            @MainActor
                            func snap(_ moving: Entity, to target: Entity) {
                                // kurz kinematic, damit Physik nicht dagegen arbeitet
                                if var body = moving.components[PhysicsBodyComponent.self] {
                                    body.mode = .kinematic
                                    moving.components.set(body)
                                }

                                let targetPos = target.position(relativeTo: nil)
                                let targetOri = target.orientation(relativeTo: nil)

                                moving.setPosition(targetPos, relativeTo: nil)
                                moving.setOrientation(targetOri, relativeTo: nil)

                                // Restgeschwindigkeit stoppen (falls vorhanden)
                                if var motion = moving.components[PhysicsMotionComponent.self] {
                                    motion.linearVelocity = .zero
                                    motion.angularVelocity = .zero
                                    moving.components.set(motion)
                                }
                            }

                            Task { @MainActor in
                                // Nur snap, wenn die Kollision gegen einen FIXEN Würfel passiert
                                if movableNames.contains(a.name), fixedNames.contains(b.name) {
                                    snap(a, to: b)
                                } else if movableNames.contains(b.name), fixedNames.contains(a.name) {
                                    snap(b, to: a)
                                }
                            }
                        }
                    )
                }
            }
        }
    }

    /// Falls die Collision Shapes schon in Reality Composer Pro gesetzt sind, ist das optional.
    private func ensureCollision(on entity: Entity) {
        guard entity.components[CollisionComponent.self] == nil else { return }

        // Größe aus Visual Bounds ableiten (Fallback: 10cm)
        let bounds = entity.visualBounds(relativeTo: entity)
        let e = bounds.extents
        let size = SIMD3<Float>(
            max(e.x, 0.1),
            max(e.y, 0.1),
            max(e.z, 0.1)
        )

        entity.components.set(
            CollisionComponent(shapes: [.generateBox(size: size)])
        )
    }
}


#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
