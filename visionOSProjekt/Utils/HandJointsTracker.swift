import Foundation
import Combine
import ARKit
import RealityKit
import SwiftUI

@MainActor
final class HandJointsTracker: ObservableObject {
    // Variante B: explizites objectWillChange
    let objectWillChange = ObservableObjectPublisher()

    private let session = ARKitSession()
    private let provider = HandTrackingProvider()

    let rootEntity = Entity()
    private var jointEntities: [String: ModelEntity] = [:]

    func setupEntities(enablePhysics: Bool) {
        guard jointEntities.isEmpty else { return } // nur einmal anlegen

        for chirality in [HandAnchor.Chirality.left, .right] {
            for jointName in HandSkeleton.JointName.allCases {
                let key = "\(jointName)-\(chirality)"

                let e = ModelEntity(mesh: .generateSphere(radius: 0.008))
                e.name = key

                if enablePhysics {
                    e.components.set(CollisionComponent(shapes: [.generateSphere(radius: 0.008)]))
                    e.components.set(PhysicsBodyComponent(mode: .kinematic))
                }

                jointEntities[key] = e
                rootEntity.addChild(e)
            }
        }
    }

    func start() async {
        guard HandTrackingProvider.isSupported else { return }

        do {
            try await session.run([provider])

            for await update in provider.anchorUpdates {
                switch update.event {
                case .added, .updated:
                    apply(anchor: update.anchor)
                default:
                    break
                }
            }
        } catch {
            // optional: print(error)
        }
    }

    private func apply(anchor: HandAnchor) {
        for jointName in HandSkeleton.JointName.allCases {
            guard
                let joint = anchor.handSkeleton?.joint(jointName),
                joint.isTracked
            else { continue }

            let key = "\(jointName)-\(anchor.chirality)"
            guard let e = jointEntities[key] else { continue }

            let world = simd_mul(anchor.originFromAnchorTransform, joint.anchorFromJointTransform)
            e.transform = Transform(matrix: world)
        }

        // Falls SwiftUI jemals reagieren soll (optional):
        // objectWillChange.send()
    }
}
