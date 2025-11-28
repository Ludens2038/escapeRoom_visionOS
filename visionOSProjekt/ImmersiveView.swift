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
                
                if let cubeRed = immersiveContentEntity.findEntity(named: "CubeRed") {
                    cubeRed.components.set(ManipulationComponent())
                    
                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    cubeRed.components.set(manipulation)
                    
                    //beaker
                    if cubeRed.components[PhysicsBodyComponent.self] == nil {
                        cubeRed.components[PhysicsBodyComponent.self] =
                        PhysicsBodyComponent(mode: .dynamic)
                    }
                    
                    willBegin = content.subscribe(
                        to: ManipulationEvents.WillBegin.self
                    ) { _ in
                        if var body = cubeRed.components[PhysicsBodyComponent.self] {
                            body.mode = .kinematic
                            cubeRed.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    
                    willRelease = content.subscribe(
                        to: ManipulationEvents.WillRelease.self
                    ) { _ in
                        if var body = cubeRed.components[PhysicsBodyComponent.self] {
                            body.mode = .dynamic
                            cubeRed.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    content.add(immersiveContentEntity) //add scene to view
                }
                
                
                if let cubeYellow = immersiveContentEntity.findEntity(named: "CubeYellow") {
                    cubeYellow.components.set(ManipulationComponent())
                    
                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    cubeYellow.components.set(manipulation)
                    
                    //beaker
                    if cubeYellow.components[PhysicsBodyComponent.self] == nil {
                        cubeYellow.components[PhysicsBodyComponent.self] =
                        PhysicsBodyComponent(mode: .dynamic)
                    }
                    
                    willBegin = content.subscribe(
                        to: ManipulationEvents.WillBegin.self
                    ) { _ in
                        if var body = cubeYellow.components[PhysicsBodyComponent.self] {
                            body.mode = .kinematic
                            cubeYellow.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    
                    willRelease = content.subscribe(
                        to: ManipulationEvents.WillRelease.self
                    ) { _ in
                        if var body = cubeYellow.components[PhysicsBodyComponent.self] {
                            body.mode = .dynamic
                            cubeYellow.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    content.add(immersiveContentEntity) //add scene to view
                }
                
                
                if let cubeBlue = immersiveContentEntity.findEntity(named: "CubeBlue") {
                    cubeBlue.components.set(ManipulationComponent())
                    
                    var manipulation = ManipulationComponent()
                    manipulation.releaseBehavior = .stay
                    cubeBlue.components.set(manipulation)
                    
                    //beaker
                    if cubeBlue.components[PhysicsBodyComponent.self] == nil {
                        cubeBlue.components[PhysicsBodyComponent.self] =
                        PhysicsBodyComponent(mode: .dynamic)
                    }
                    
                    willBegin = content.subscribe(
                        to: ManipulationEvents.WillBegin.self
                    ) { _ in
                        if var body = cubeBlue.components[PhysicsBodyComponent.self] {
                            body.mode = .kinematic
                            cubeBlue.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    
                    willRelease = content.subscribe(
                        to: ManipulationEvents.WillRelease.self
                    ) { _ in
                        if var body = cubeBlue.components[PhysicsBodyComponent.self] {
                            body.mode = .dynamic
                            cubeBlue.components[PhysicsBodyComponent.self] = body
                        }
                    }
                    content.add(immersiveContentEntity) //add scene to view
                }
                
            }
        }
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
