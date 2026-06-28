# Tài liệu tránh dùng tài sản thương hiệu Microsoft

Mục tiêu của dự án là tạo môi trường Linux thân thiện với người dùng quen Windows, nhưng không sử dụng hoặc mô phỏng tài sản nhận diện Microsoft.

Tài liệu này không phải tư vấn pháp lý. Khi triển khai thương mại, nên để khách hàng hoặc bộ phận pháp chế duyệt trước image bàn giao.

## Nguyên tắc

- Làm giao diện quen thuộc ở mức luồng sử dụng: menu ứng dụng, thanh taskbar/panel, shortcut desktop, thư mục bài tập.
- Không sao chép nhận diện thương hiệu, tên sản phẩm, icon, logo, wallpaper hoặc âm thanh của Microsoft.
- Không cài phần mềm không rõ license, crack, KMS, key lậu hoặc bộ icon/wallpaper lấy từ Windows.
- Không làm người dùng hiểu nhầm đây là Windows, Microsoft Office hoặc sản phẩm được Microsoft chứng thực.

## Không được dùng

- Logo Windows, Microsoft, Office, Word, Excel, PowerPoint, Teams, OneDrive.
- Icon `.ico`, `.png`, `.dll`, `.exe` trích xuất từ Windows hoặc Microsoft Office.
- Wallpaper mặc định của Windows, kể cả ảnh biến thể hoặc ảnh sửa nhẹ.
- Tên hệ thống, theme hoặc shortcut như:
  - Windows Linux
  - WinLab
  - Windows-like
  - Microsoft Office
  - Word
  - Excel
  - PowerPoint
- Font copy từ thư mục Windows hoặc Office.
- Gói `ttf-mscorefonts-installer` trong image mặc định nếu chính sách khách hàng là tránh tài sản Microsoft tối đa.

## Nên dùng

- Tên trung tính: EduLab Linux, Phòng máy IC3, Máy học sinh.
- Shortcut trung tính:
  - ONLYOFFICE
  - Trình duyệt
  - Bài tập
  - LMS
- Tên bài học trung tính:
  - Soạn thảo văn bản
  - Bảng tính
  - Trình chiếu
- Font mở:
  - Noto
  - Liberation
  - Carlito, thay thế metric-compatible cho Calibri
  - Caladea, thay thế metric-compatible cho Cambria
- Theme/icon mở từ repository distro, ví dụ Arc và Papirus, miễn không cấu hình để giả mạo Windows.
- Wallpaper tự tạo hoặc ảnh có license rõ ràng, không giống wallpaper Windows.

## Về Microsoft Edge

Microsoft Edge là phần mềm hợp pháp nếu cài từ repository chính thức và chấp thuận license của Microsoft. Tuy nhiên Edge dùng tên, icon và nhận diện Microsoft.

Vì vậy trong cấu hình mặc định của dự án:

- Không cài Edge.
- Dùng Chrome hoặc Chromium làm trình duyệt chính.
- Chỉ cài Edge nếu khách hàng yêu cầu rõ ràng và chấp thuận việc xuất hiện nhận diện Microsoft.
- Khi cài Edge, không đổi tên/icon Edge thành thứ khác.

Trong script, Edge bị chặn nếu không truyền cờ:

```bash
--browser edge --allow-microsoft-edge
```

## Quy trình kiểm tra trước bàn giao

- [ ] Mở Desktop tài khoản học sinh và chụp màn hình lưu hồ sơ.
- [ ] Kiểm tra toàn bộ shortcut trên Desktop.
- [ ] Kiểm tra menu ứng dụng không có icon/tên Microsoft tự thêm ngoài phần mềm được khách hàng chấp thuận.
- [ ] Kiểm tra wallpaper không phải ảnh Windows hoặc ảnh phái sinh.
- [ ] Kiểm tra không có file logo/icon Microsoft trong thư mục project tùy biến.
- [ ] Kiểm tra tài liệu hướng dẫn học sinh không gọi ONLYOFFICE là Word/Excel/PowerPoint.
- [ ] Kiểm tra danh sách gói đã cài:

```bash
dpkg -l | grep -Ei 'mscorefonts|microsoft|edge|office|windows'
```

- [ ] Nếu có kết quả, xác định đó là phần mềm hợp pháp và đã được khách hàng chấp thuận.

## Cách nói với khách hàng

Cách diễn đạt nên dùng:

- "Giao diện được bố trí quen thuộc với người dùng desktop phổ thông."
- "Bộ công cụ văn phòng dùng ONLYOFFICE Desktop Editors."
- "Font mở được chọn để tương thích bố cục tài liệu phổ biến."

Tránh diễn đạt:

- "Giống Windows."
- "Thay Microsoft Office bằng bản tương tự Microsoft Office."
- "Có Word/Excel/PowerPoint trên Linux."
- "Dùng icon Windows cho dễ nhận biết."

## Lưu hồ sơ triển khai

Mỗi image bàn giao nên lưu:

- Tên distro và phiên bản ISO.
- Ngày tạo image.
- Danh sách package bên thứ ba.
- URL repository bên thứ ba.
- Ảnh chụp Desktop tài khoản học sinh.
- Kết quả checklist thương hiệu.
- Người duyệt cuối cùng.
