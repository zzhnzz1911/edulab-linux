# Ghi chú nhận diện khi dùng giao diện Windows 10-like

Dự án hiện cấu hình **EduLab Windows 10-like Desktop** để người dùng quen Windows 10 dễ chuyển sang Linux. Tài liệu này không phải tư vấn pháp lý; trước khi triển khai thương mại hoặc bàn giao image cho khách hàng, hãy để bên chịu trách nhiệm pháp lý/branding duyệt lại.

## Thành phần đang dùng

- Theme GTK/Xfwm: `B00merang-Project/Windows-10`, cài vào `/usr/share/themes/Windows 10`.
- Icon theme: `B00merang-Artwork/Windows-10`, cài vào `/usr/share/icons/Windows 10`.
- Wallpaper: `assets/windows-10-blue-gradient.jpg`, được copy từ file wallpaper người dùng cung cấp trong `downloads/`.
- Font UI: `Noto Sans 10`; không copy font từ Windows hoặc Microsoft Office.
- Ứng dụng văn phòng: ONLYOFFICE Desktop Editors, không đổi tên thành Word/Excel/PowerPoint.

## Việc cần kiểm tra trước khi bàn giao

- [ ] Xác nhận theme/icon/wallpaper được phép dùng trong bối cảnh triển khai của bạn.
- [ ] Chụp màn hình Desktop tài khoản hiện tại/admin sau khi cài và lưu vào hồ sơ triển khai.
- [ ] Kiểm tra không có file `.ico`, `.dll`, `.exe` hoặc font trích xuất trực tiếp từ Windows/Office được thêm vào project.
- [ ] Kiểm tra README/tài liệu bàn giao không nói đây là Windows thật hoặc sản phẩm được Microsoft chứng thực.
- [ ] Nếu cài Microsoft Edge, phải chạy rõ ràng với `--browser edge --allow-microsoft-edge` và chấp nhận license của Microsoft.

## Cách mô tả khuyến nghị

- "Giao diện Linux được tùy biến theo phong cách Windows 10 để dễ làm quen."
- "Bộ văn phòng dùng ONLYOFFICE Desktop Editors."
- "Các shortcut chính gồm File Explorer, Settings, trình duyệt, Bài tập và LMS."

Tránh mô tả rằng hệ thống là Windows, Windows bản rút gọn, hoặc có Microsoft Office nếu thực tế đang chạy Linux và ONLYOFFICE.
