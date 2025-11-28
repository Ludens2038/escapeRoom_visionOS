import SwiftUI
import RealityKit
import RealityKitContent
import Spatial

struct ImmersiveView: View {
    @State private var startPosition: SIMD3<Float>? = nil
    @State private var willBegin: EventSubscription? = nil
    @State private var willRelease: EventSubscription? = nil
    
    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                if let beaker = immersiveContentEntity.findEntity(named: "Beaker") {
                    beaker.components.set(ManipulationComponent())
                    
                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    beaker.components.set(manipulation)
                    
                    // floor
                    let floor = ModelEntity(
                            mesh: .generatePlane(width: 1000, depth: 1000),
                            materials: [OcclusionMaterial()]
                        )
                        floor.generateCollisionShapes(recursive: false)
                        floor.components[PhysicsBodyComponent.self] = PhysicsBodyComponent(
                            massProperties: .default,
                            material: .default,
                            mode: .static
                        )
                    immersiveContentEntity.addChild(floor)
                    
                    //beaker
                    if beaker.components[PhysicsBodyComponent.self] == nil {
                        beaker.components[PhysicsBodyComponent.self] =
                        PhysicsBodyComponent(mode: .dynamic)
                    }
                    
                    willBegin = content.subscribe(
                        to: ManipulationEvents.WillBegin.self
                    ) { _ in
                        if var body = beaker.components[PhysicsBodyComponent.self] {
                            body.mode = .kinematic
                            beaker.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    
                    willRelease = content.subscribe(
                        to: ManipulationEvents.WillRelease.self
                    ) { _ in
                        if var body = beaker.components[PhysicsBodyComponent.self] {
                            body.mode = .dynamic
                            beaker.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    content.add(immersiveContentEntity)
                }
            }
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
