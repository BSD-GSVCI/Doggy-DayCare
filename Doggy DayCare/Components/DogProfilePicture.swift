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
        .sheet(isPresented: $showingEnlargedImage) {
            if let profilePictureData = dog.profilePictureData,
               let uiImage = UIImage(data: profilePictureData) {
                NavigationStack {
                    VStack {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding()
                        
                        Text(dog.name)
                            .font(.headline)
                            .padding(.bottom)
                    }
                    .navigationTitle("Profile Picture")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                showingEnlargedImage = false
                            }
                        }
                    }
                }
            }
        }
    }
}

 