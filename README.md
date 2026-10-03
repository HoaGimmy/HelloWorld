# MPWindows CRM — Flutter iOS

CRM cho MPWindows, tối ưu quy trình nhôm kính từ khách hàng đến thu tiền.

## Chức năng hiện có
- Dashboard: khách hàng, khảo sát, báo giá, chốt hợp đồng
- Hồ sơ khách hàng + tìm kiếm + CRUD
- Pipeline 10 giai đoạn + chuyển trạng thái
- Timeline chăm sóc khách
- Công việc, deadline, ưu tiên, đánh dấu hoàn thành
- Lịch hẹn theo ngày
- Công trình: hạng mục, hệ nhôm, phụ kiện, tiến độ
- Báo giá
- Hợp đồng + bảo hành
- Thu tiền và công nợ tự tính
- SQLite offline trên thiết bị
- Xuất Excel: KhachHang, Timeline, CongViec, LichHen, CongTrinh, BaoGia, HopDong, ThuTien
- Schema Supabase sẵn cho cloud/multi-user

## Chạy local
```bash
flutter create --platforms=ios,android .
flutter pub get
flutter run
```

## Build iOS
GitHub Actions chạy:
- flutter analyze
- flutter test
- build iOS release không ký
- đóng gói artifact `MPWindowsCRM-unsigned.ipa`

Mở tab **Actions → Flutter CI → Artifacts** để tải file iOS unsigned.

Để cài trực tiếp lên iPhone cần Apple Developer certificate + provisioning profile để ký IPA.

## Branch phát triển
`mpwindows-crm-mvp`

## Bước production tiếp theo
- Supabase Auth + đồng bộ nhiều thiết bị
- Phân quyền Admin / Sales / Kỹ thuật / Kế toán
- Ảnh và file công trình
- Push notification nhắc lịch/công nợ
- Báo giá PDF và chữ ký
