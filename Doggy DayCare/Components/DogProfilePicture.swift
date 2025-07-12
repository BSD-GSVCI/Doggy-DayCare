import SwiftUI

struct DogProfilePicture: View {
    let dog: Dog
    let size: CGFloat
    @State private var showingEnlargedImage = false
    
    var body: some View {
        Group {
            if let profilePictureData = dog.profilePictureData,
               let uiImage = UIImage(data: profilePictureData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: size, height: size)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .onTapGesture {
                        showingEnlargedImage = true
                    }
            } else {
                // Default dog icon
                Image(systemName: "pawprint.circle.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: size, height: size)
                    .foregroundStyle(.gray)
            }
        }
        .onChange(of: showingEnlargedImage) { oldValue, newValue in
            if newValue {
                NotificationCenter.default.post(name: .showImageOverlay, object: (dog, showingEnlargedImage))
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .hideImageOverlay)) { notification in
            if let dog = notification.object as? Dog, dog.id == self.dog.id {
                showingEnlargedImage = false
            }
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let showImageOverlay = Notification.Name("showImageOverlay")
    static let hideImageOverlay = Notification.Name("hideImageOverlay")
}

// MARK: - View Modifier for Image Overlay
struct ImageOverlayModifier: ViewModifier {
    @State private var showingOverlay = false
    @State private var currentDog: Dog?
    
    func body(content: Content) -> some View {
        content
            .overlay {
                if showingOverlay, let dog = currentDog, let profilePictureData = dog.profilePictureData, let uiImage = UIImage(data: profilePictureData) {
                    Color.black.opacity(0.8)
                        .ignoresSafeArea()
                        .onTapGesture {
                            showingOverlay = false
                            NotificationCenter.default.post(name: .hideImageOverlay, object: currentDog)
                        }
                        .overlay {
                            VStack {
                                Spacer()
                                
                                Image(uiImage: uiImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .frame(maxWidth: UIScreen.main.bounds.width * 0.8, maxHeight: UIScreen.main.bounds.height * 0.6)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .shadow(radius: 20)
                                
                                Spacer()
                                
                                Button("Close") {
                                    showingOverlay = false
                                    NotificationCenter.default.post(name: .hideImageOverlay, object: currentDog)
                                }
                                .foregroundStyle(.white)
                                .padding()
                                .background(.blue)
                                .clipShape(Capsule())
                                .padding(.bottom, 50)
                            }
                        }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showImageOverlay)) { notification in
                if let (dog, showing) = notification.object as? (Dog, Bool) {
                    currentDog = dog
                    showingOverlay = showing
                }
            }
    }
}

// MARK: - View Extension
extension View {
    func imageOverlay() -> some View {
        modifier(ImageOverlayModifier())
    }
}

 