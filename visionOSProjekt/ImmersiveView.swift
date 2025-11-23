import SwiftUI
import RealityKit
import RealityKitContent
import Spatial

struct ImmersiveView: View {
    @State private var startPosition: SIMD3<Float>? = nil
    
    var body: some View {
        RealityView { content in
            if let immersiveContentEntity = try? await Entity(named: "Immersive", in: realityKitContentBundle) {
                content.add(immersiveContentEntity)
            }
        }
        .gesture(
            DragGesture()
                .targetedToAnyEntity()
                .onChanged { value in
                    let entity = value.entity
                    let t = value.translation
                    
                    if startPosition == nil {
                        startPosition = entity.position
                    }
                    
                    guard let start = startPosition else { return }
                    
                    let factor: Float = 0.001
                    let newX = start.x + Float(t.width)  * factor
                    let newZ = start.z + Float(-t.height) * factor
                    
                    entity.position.x = newX
                    entity.position.z = newZ
                }
                .onEnded { _ in
                    startPosition = nil
                }
        )
    }
}

#Preview(immersionStyle: .full) {
    ImmersiveView()
        .environment(AppModel())
}
