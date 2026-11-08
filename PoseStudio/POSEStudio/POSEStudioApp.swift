import SwiftUI
import AVFoundation
import Photos
import UIKit

@main struct POSEStudioApp: App {
    var body: some Scene { WindowGroup { MainView() } }
}

struct Pose: Identifiable {
    let id: Int
    let name: String
    let tip: String
    let group: String
    let points: [CGPoint]
}

let poses: [Pose] = [
    Pose(id: 0, name: "Đứng tự nhiên", tip: "Thả lỏng vai, dồn trọng tâm lên một chân.", group: "Nữ", points: [.init(x:0.50,y:0.28),.init(x:0.5,y:0.38),.init(x:0.5,y:0.57),.init(x:0.44,y:0.81),.init(x:0.58,y:0.85),.init(x:0.38,y:0.51),.init(x:0.64,y:0.53)]),
    Pose(id: 1, name: "Chống hông", tip: "Một tay chống hông, xoay nhẹ người.", group: "Nữ", points: [.init(x:0.5,y:0.27),.init(x:0.5,y:0.38),.init(x:0.5,y:0.57),.init(x:0.46,y:0.85),.init(x:0.61,y:0.80),.init(x:0.43,y:0.55),.init(x:0.65,y:0.45)]),
    Pose(id: 2, name: "Bước đi", tip: "Bước một chân về trước và nhìn ngang.", group: "Đường phố", points: [.init(x:0.50,y:0.26),.init(x:0.50,y:0.38),.init(x:0.51,y:0.56),.init(x:0.38,y:0.87),.init(x:0.67,y:0.77),.init(x:0.35,y:0.52),.init(x:0.68,y:0.56)]),
    Pose(id: 3, name: "Tay trong túi", tip: "Đưa một tay vào túi quần, vai thư giãn.", group: "Nam", points: [.init(x:0.51,y:0.27),.init(x:0.51,y:0.39),.init(x:0.50,y:0.57),.init(x:0.47,y:0.86),.init(x:0.61,y:0.85),.init(x:0.44,y:0.57),.init(x:0.66,y:0.51)]),
    Pose(id: 4, name: "Khoanh tay", tip: "Khoanh tay nhẹ, đứng thẳng lưng.", group: "Nam", points: [.init(x:0.50,y:0.28),.init(x:0.50,y:0.39),.init(x:0.50,y:0.57),.init(x:0.43,y:0.85),.init(x:0.59,y:0.85),.init(x:0.55,y:0.46),.init(x:0.44,y:0.46)]),
    Pose(id: 5, name: "Ngồi nghiêng", tip: "Ngồi nghiêng 30 độ, giữ lưng thẳng.", group: "Ngồi", points: [.init(x:0.53,y:0.33),.init(x:0.50,y:0.43),.init(x:0.48,y:0.62),.init(x:0.67,y:0.72),.init(x:0.42,y:0.82),.init(x:0.39,y:0.55),.init(x:0.63,y:0.58)])
]

final class CameraService: NSObject, ObservableObject, AVCapturePhotoCaptureDelegate {
    let session = AVCaptureSession()
    @Published var ready = false
    @Published var front = true
    @Published var status = ""
    private let queue = DispatchQueue(label:"pose.camera.queue")
    private let output = AVCapturePhotoOutput()
    private var configured = false
    func start() {
        let auth = AVCaptureDevice.authorizationStatus(for: .video)
        if auth == .notDetermined {
            AVCaptureDevice.requestAccess(for: .video) { [weak self] ok in
                if ok { self?.start() } else { DispatchQueue.main.async { self?.status = "Bạn cần cấp quyền Camera trong Cài đặt." } }
            }
        } else if auth == .authorized {
            queue.async { [weak self] in
                guard let self else { return }
                if !self.configured { self.setup() }
                if self.configured && !self.session.isRunning { self.session.startRunning() }
                DispatchQueue.main.async { self.ready = self.session.isRunning }
            }
        } else { status = "Bạn cần cấp quyền Camera trong Cài đặt." }
    }
    private func setup() {
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.sessionPreset = .photo
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input), session.canAddOutput(output) else { return }
        session.addInput(input)
        session.addOutput(output)
        configured = true
    }
    func flip() {
        queue.async { [weak self] in
            guard let self, self.configured,
                  let current = self.session.inputs.first as? AVCaptureDeviceInput else { return }
            let target: AVCaptureDevice.Position = self.front ? .back : .front
            guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: target),
                  let next = try? AVCaptureDeviceInput(device: device) else { return }
            self.session.beginConfiguration()
            self.session.removeInput(current)
            if self.session.canAddInput(next) { self.session.addInput(next); DispatchQueue.main.async { self.front.toggle() } }
            else { self.session.addInput(current) }
            self.session.commitConfiguration()
        }
    }
    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async { self.ready = false }
        }
    }
    func shoot() {
        queue.async { [weak self] in
            guard let self, self.ready else { return }
            let settings = AVCapturePhotoSettings()
            settings.flashMode = .off
            if let conn = self.output.connection(with: .video), conn.isVideoMirroringSupported {
                conn.isVideoMirrored = self.front
            }
            self.output.capturePhoto(with: settings, delegate: self)
        }
    }
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil, let data = photo.fileDataRepresentation(), let image = UIImage(data:data) else {
            DispatchQueue.main.async { self.status = "Không thể chụp ảnh." }; return
        }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { permission in
            guard permission == .authorized || permission == .limited else {
                DispatchQueue.main.async { self.status = "Vui lòng cấp quyền lưu Ảnh trong Cài đặt." }; return
            }
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAsset(from:image) }) { ok,_ in
                DispatchQueue.main.async { self.status = ok ? "Đã lưu ảnh vào thư viện Ảnh." : "Lưu ảnh thất bại." }
            }
        }
    }
}

final class Preview: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    var preview: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
}
struct CameraLayer: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context:Context) -> Preview {
        let view = Preview()
        view.preview.session = session
        view.preview.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view:Preview,context:Context) {}
}
struct PoseGuide: View {
    let pose: Pose
    var body: some View {
        GeometryReader { proxy in
            let p = pose.points.map { CGPoint(x:$0.x * proxy.size.width,y:$0.y * proxy.size.height) }
            Path { path in
                guard p.count >= 7 else { return }
                path.move(to:p[0]); path.addLine(to:p[1]); path.addLine(to:p[2])
                path.move(to:p[1]); path.addLine(to:p[5])
                path.move(to:p[1]); path.addLine(to:p[6])
                path.move(to:p[2]); path.addLine(to:p[3])
                path.move(to:p[2]); path.addLine(to:p[4])
            }.stroke(.yellow,style:StrokeStyle(lineWidth:5,lineCap:.round,lineJoin:.round))
            Circle().stroke(.yellow,lineWidth:4).frame(width:proxy.size.width*0.1,height:proxy.size.width*0.1)
                .position(p[0])
            ForEach(1..<7,id:\.self) { index in
                Circle().fill(.yellow).frame(width:10,height:10).position(p[index])
            }
        }.allowsHitTesting(false)
    }
}
struct MainView: View {
    @StateObject private var camera = CameraService()
    @State private var selected = poses[0]
    @State private var opacity = 0.68
    @State private var showGuide = true
    @State private var timerSeconds = 3
    @State private var countdown = 0
    @State private var shooting = false
    @State private var favorites: Set<Int> = Set(UserDefaults.standard.array(forKey:"favorites") as? [Int] ?? [])
    @State private var group = "Tất cả"
    private let groups = ["Tất cả","Nữ","Nam","Ngồi","Đường phố","Yêu thích"]
    var filtered: [Pose] { poses.filter { group == "Tất cả" || (group == "Yêu thích" ? favorites.contains($0.id) : $0.group == group) } }
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing:10) {
                HStack {
                    VStack(alignment:.leading,spacing:2) {
                        Text("POSE STUDIO").font(.title2.bold())
                        Text("Trợ lý tạo dáng trên iPhone").font(.caption).foregroundStyle(.white.opacity(0.7))
                    }
                    Spacer()
                    Button { camera.flip() } label: { Image(systemName:"arrow.triangle.2.circlepath.camera").font(.title2) }
                }.padding(.horizontal)
                ZStack {
                    CameraLayer(session:camera.session)
                    if showGuide { PoseGuide(pose:selected).opacity(opacity) }
                    VStack {
                        HStack {
                            Text(selected.name).font(.headline)
                            Spacer()
                            Button { toggleFavorite() } label: {
                                Image(systemName:favorites.contains(selected.id) ? "heart.fill":"heart")
                                    .foregroundStyle(.pink)
                            }
                            Button { showGuide.toggle() } label: {
                                Image(systemName:showGuide ? "figure.stand":"eye.slash")
                            }
                        }.padding(12).background(.black.opacity(0.5)).clipShape(.rect(cornerRadius:12))
                        Spacer()
                        if countdown > 0 { Text("\(countdown)").font(.system(size:90,weight:.bold)).shadow(radius:12) }
                        Spacer()
                        Text(selected.tip).font(.subheadline).multilineTextAlignment(.center)
                            .padding(10).frame(maxWidth:.infinity).background(.black.opacity(0.5))
                            .clipShape(.rect(cornerRadius:12))
                    }.padding(12)
                }.frame(maxWidth:.infinity).clipShape(.rect(cornerRadius:20)).padding(.horizontal,10)
                HStack {
                    Image(systemName:"figure.stand")
                    Slider(value:$opacity,in:0.1...1)
                    Text("\(Int(opacity*100))%").font(.caption.monospacedDigit())
                }.padding(.horizontal)
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack {
                        ForEach(groups,id:\.self) { item in
                            Button(item) { group = item }
                                .font(.caption.bold()).padding(.horizontal,13).padding(.vertical,8)
                                .background(group == item ? Color.yellow : Color.white.opacity(0.16))
                                .foregroundStyle(group == item ? .black : .white)
                                .clipShape(Capsule())
                        }
                    }.padding(.horizontal,12)
                }
                ScrollView(.horizontal,showsIndicators:false) {
                    HStack(spacing:10) {
                        ForEach(filtered) { pose in
                            Button { selected = pose } label: {
                                VStack(spacing:4) {
                                    ZStack {
                                        RoundedRectangle(cornerRadius:10).fill(.white.opacity(0.10))
                                        PoseGuide(pose:pose).padding(3)
                                    }.frame(width:72,height:88)
                                    Text(pose.name).font(.system(size:10)).lineLimit(1)
                                }.frame(width:85)
                                    .padding(5)
                                    .overlay(RoundedRectangle(cornerRadius:12)
                                        .stroke(selected.id == pose.id ? .yellow : .clear,lineWidth:2))
                            }.tint(.white)
                        }
                    }.padding(.horizontal,12)
                }.frame(height:120)
                HStack(spacing:20) {
                    Picker("Hẹn giờ",selection:$timerSeconds) {
                        Text("Tắt").tag(0); Text("3s").tag(3); Text("5s").tag(5); Text("10s").tag(10)
                    }.tint(.yellow)
                    Spacer()
                    Button { startShot() } label: {
                        ZStack {
                            Circle().fill(.white).frame(width:70,height:70)
                            Circle().stroke(.black,lineWidth:3).frame(width:58,height:58)
                        }
                    }.disabled(shooting || !camera.ready)
                    Spacer()
                    Image(systemName:"camera.fill").foregroundStyle(.yellow)
                }.padding(.horizontal,24)
                if !camera.status.isEmpty {
                    Text(camera.status).font(.caption).foregroundStyle(.yellow)
                        .lineLimit(2).padding(.horizontal)
                }
            }.padding(.top,7).padding(.bottom,8)
        }.foregroundStyle(.white)
        .onAppear { camera.start() }
        .onDisappear { camera.stop() }
    }
    private func toggleFavorite() {
        if favorites.contains(selected.id) { favorites.remove(selected.id) }
        else { favorites.insert(selected.id) }
        UserDefaults.standard.set(Array(favorites),forKey:"favorites")
    }
    private func startShot() {
        guard !shooting else { return }
        shooting = true
        countdown = timerSeconds
        Task { @MainActor in
            while countdown > 0 {
                try? await Task.sleep(nanoseconds:1_000_000_000)
                countdown -= 1
            }
            camera.shoot()
            shooting = false
        }
    }
}
