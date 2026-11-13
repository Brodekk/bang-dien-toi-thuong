-- Tử Vi: màn hình xem lá số đã luận sẵn, nạp lười bởi main.lua (dofile)
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local Screen = Device.screen

local BLACK = Blitbuffer.COLOR_BLACK
local WHITE = Blitbuffer.COLOR_WHITE
local GRAY5 = Blitbuffer.COLOR_GRAY_5
local GRAYE = Blitbuffer.COLOR_GRAY_E

local function face(px)
    local s = math.floor(px * 100 / Screen:scaleBySize(100) + 0.5)
    if s < 6 then s = 6 end
    return Font:getFace("cfont", s)
end

local function txt(bb, s, x, y, px, opts)
    opts = opts or {}
    local tw = TextWidget:new{ text = tostring(s), face = face(px), bold = opts.bold or false,
        fgcolor = opts.color or BLACK, max_width = opts.max_width, padding = 0 }
    local w = tw:getWidth()
    local h = tw:getSize().h
    local px0 = x
    if opts.right then px0 = x - w elseif opts.center then px0 = x - math.floor(w / 2) end
    tw:paintTo(bb, math.floor(px0), math.floor(y))
    tw:free()
    return w, h
end

local function level(s)
    if s >= 3 then return "MẠNH" elseif s >= 1 then return "KHÁ" elseif s > -1 then return "TRUNG BÌNH"
    elseif s > -3 then return "YẾU" end
    return "RẤT YẾU"
end

local function fmt(s)
    local t = string.format("%+.1f", s):gsub("%.", ",")
    return t
end


-- ===== nội dung lá số (Claude luận, dựa trên vị trí sao của lá số Nhâm Ngọ, Dương Nam, giờ Tị, 24/10 âm lịch) =====
local DATA = {
{ tab = "TỔNG QUAN", items = {
{ t = "Lá số trong một câu", body = [[Nền vững, sân khấu nhiều lửa.

Những cung làm "lưới đỡ" (Phụ mẫu, Phúc đức, Tật ách) rất mạnh, nhưng ba cung bạn trực tiếp sống và va chạm hằng ngày (Mệnh, Quan lộc, Phu thê/Thân) lại nhiều sát tinh. Nói gọn: bạn hiếm khi rơi xuống đáy vì luôn có người, có phúc, có sức đỡ; nhưng con đường đi lên phải tự mở, và cái làm bạn vấp nhiều nhất là chính sự nóng và lời nói của mình chứ không phải hoàn cảnh.]] },
{ t = "Điểm chế hóa toàn lá số", s = 1.0, body = [[Tổng 12 cung: +12,4 (trung bình +1,0 mỗi cung), tức nghiêng về tốt nhưng lệch rõ:
• Mạnh: Tật ách +6,3 · Phụ mẫu +4,5 · Phúc đức +2,6 · Huynh đệ +1,9
• Trung bình: Điền +1,5 · Nô +1,4 · Tử tức +1,3 · Tài +0,6 · Thiên di −1,0
• Yếu: Phu thê/Thân −2,4 · Mệnh −2,5 · Quan lộc −4,0

Đây là thang điểm tôi tự dựng, không phải điểm huyền khí của Tử Vi Cổ Học (công thức đó không công khai), nên con số sẽ khác. Chi tiết cách tính ở tab BẢNG ĐIỂM.]] },
{ t = "Chủ thể: bạn là ai trước khi xét sao", body = [[Dương Nam, tuổi Nhâm Ngọ, mệnh Dương Liễu Mộc (cây liễu: mềm, dẻo, uốn theo gió mà không gãy), Thủy Nhị Cục.

• Cục Thủy sinh Mệnh Mộc: hoàn cảnh nuôi bạn, dễ gặp người nâng đỡ. Đây là điểm cộng nền, nó giải thích vì sao các cung "lưới đỡ" mạnh.
• Mệnh đóng ở Ngọ (Hỏa): Mộc sinh Hỏa, tức bạn tự đốt sức mình cho Mệnh. Bạn làm gì cũng dồn hết lửa, nhanh mệt và dễ bùng.
• Chính tinh Cự Môn (Thủy) sinh bản mệnh Mộc: sao chính hợp với bạn, thực lực là thật.
• Dương Nam, Mệnh ở cung dương: âm dương thuận lý, mọi việc ít bị "ngược chiều".

Kết luận nền: bạn có gốc tốt và được đỡ, nhưng cách bạn tiêu năng lượng hơi phung phí.]] },
{ t = "Ba trục chi phối cả đời", body = [[1. Lời nói là vũ khí và là rủi ro. Cự Môn vượng ở Mệnh cho tài ăn nói, phân tích, phản biện; đi cùng Thái Tuế, Thiên Hình, Hỏa Tinh nên lời nói sắc, thẳng, dễ chạm tự ái và dễ dính thị phi. Cùng một năng lực vừa kiếm tiền vừa gây chuyện.

2. Mặt Trời, Mặt Trăng đều tối (Thái Dương hãm ở Quan lộc Tuất, Thái Âm hãm ở Phu thê Thìn), cách "Nhật Nguyệt phản bối": sự nghiệp và tình cảm đều thành muộn, phải bôn ba. Điểm sáng: đại vận 42–51 có Hóa Lộc vào Thái Dương và Hóa Khoa vào Thái Âm, đúng kiểu phản bối gặp Lộc Khoa nên đảo chiều.

3. Lộc nằm ở Phúc đức (Hóa Lộc + Thiên Mã), chiếu vào Tài bạch và nằm trong tam hợp của cung Thân, chứ không nằm ở Mệnh. Tiền và may mắn đến khi bạn làm việc phục vụ, giúp người, di chuyển; ít đến khi bạn cố chứng tỏ mình đúng.]] },
{ t = "Lời khuyên lớn nhất", body = [[Giữ lửa, đừng tắt lửa. Năng lượng của bạn là tài sản, nhưng cần một "ống dẫn": viết thay vì cãi, phân tích thay vì phán xét, góp ý riêng thay vì nói trước đám đông.

Ba việc đáng làm sớm:
• Tập trì hoãn phản ứng 1 nhịp khi bị chọc tức (Hỏa + Hình + Thái Tuế ở Mệnh).
• Có quỹ dự phòng tự động, vì Tài bạch bị Triệt và Nô bộc giữ Lộc Tồn, nên tiền dễ trôi sang tay người khác.
• Đầu tư vào sức khỏe và nghỉ ngơi: Tật ách là cung cứu giải mạnh nhất của bạn, giữ nó tốt thì hạn nào cũng có đường lui.

Tử vi là công cụ để soi lại mình, không có kiểm chứng khoa học. Đừng dùng nó để quyết định chuyện sức khỏe hay tiền lớn.]] },
}},
{ tab = "MỆNH · THÂN", items = {
{ t = "Cung Mệnh · Ngọ · Cự Môn vượng", s = -2.5, body = [[Được: Cự Môn ở Ngọ là thế mạnh của sao này. Đầu óc đào sâu, hay hỏi "tại sao", lý lẽ chặt, nói và viết có sức thuyết phục. Thiên Cơ ở Thiên di chiếu về (cách Cự Cơ) cho thêm sự lanh lợi, xoay xở nhanh. Thiên Phúc, Hỉ Thần giúp bạn có duyên và được tha thứ khá dễ.

Mất: Mệnh có Địa Không, Hỏa Tinh, Thiên Hình và Thái Tuế, đối diện là Kình Dương, tam hợp có Đà La, Linh Tinh. Đây là lượng sát nhiều nhất lá số: nóng, gắt, tự ái cao; ý tưởng hay nhưng dễ "đầu voi đuôi chuột" (Địa Không); dễ va chạm với người có quyền, quy định (Thái Tuế + Hình).

Cân lại: thực lực (Cự Môn vượng) mạnh, nhưng điểm chế hóa thấp vì không có sao giải nào đóng ở Mệnh. Nghĩa là năng lực không thiếu, chỉ thiếu "phanh". Khi có phanh, lá số này đi rất xa.

Nên làm: dùng miệng để kiếm tiền (viết, trình bày, phân tích, tư vấn) thay vì để tranh thắng thua.]] },
{ t = "Cung Thân · Thìn · cư Phu thê", s = -2.4, body = [[Thân cư Phu thê: từ khoảng 30 tuổi trở đi, cuộc sống của bạn xoay quanh gia đình và người bạn đời. Người ở cạnh bạn ảnh hưởng mạnh tới quyết định, tâm trạng và cả tiền bạc.

Được: Thái Âm (dịu, sâu, tinh tế) cùng Giải Thần, Địa Giải, Đường Phù, Phượng Các. Tam hợp cung Thân có Thiên Đồng, Thiên Lương, Hóa Lộc, Thiên Mã ở Phúc đức, nên khi về già bạn được hưởng an nhàn và tiền đến đều hơn thời trẻ.

Mất: Thái Âm hãm ở Thìn, lại sinh ban ngày; gặp Địa Kiếp, Quả Tú, Thiên La. Nội tâm hay giữ, buồn mà không nói; tình cảm, nhà cửa thời trẻ hay hụt.

Cân lại: sao giải ở đây chế được khoảng 30% sát. Đại vận hiện tại (22–31) cho Thái Âm Hóa Quyền đúng cung này, nên bạn đang dần làm chủ được cảm xúc và chuyện tình cảm. Đây là cung yếu đang được nâng lên.]] },
{ t = "Tính cách: ưu và nhược đi thành cặp", body = [[• Sắc sảo ↔ hay bắt lỗi người khác.
• Thẳng thắn ↔ nói xong mới nghĩ.
• Nhiệt (Hỏa Tinh) ↔ nhanh chán, nóng giận.
• Nghĩ khác người (Địa Không) ↔ khó làm việc tới nơi tới chốn.
• Nghiêm với mình (Thiên Hình) ↔ khắt khe, khó tha thứ cho bản thân.
• Bên ngoài mạnh (Mệnh) ↔ bên trong mềm, dễ tổn thương (Thân Thái Âm).

Mệnh chủ Phá Quân: thích phá cái cũ làm cái mới. Thân chủ Hỏa Tinh: về sau, lửa vẫn là động cơ chính. Đây không phải "tật" cần sửa mà là cấu tạo; việc cần làm là đặt nó vào chỗ đúng.]] },
{ t = "Khi gặp hạn xấu, bạn chịu được tới đâu?", body = [[Đây là phần các trang tự động thường bỏ qua.

• Sức tự đỡ của Mệnh: thấp (điểm −2,5). Hạn xấu chạm vào Mệnh thì bạn phản ứng mạnh và dễ tự làm nặng thêm.
• Lưới đỡ bên ngoài: rất dày. Tật ách có Tử Vi, Tả Phù, Hữu Bật, Hóa Khoa, Hóa Quyền, Long Đức (gặp nạn có người giỏi cứu). Phúc đức có Đồng Lương Hóa Lộc. Phụ mẫu có Thiên Tướng, Quốc Ấn.

Nghĩa là: hạn xấu đến với bạn thường "ồn" hơn là "nặng". Nó gây xáo trộn cảm xúc, cãi vã, mất tiền vặt, nhưng hiếm khi làm sập nền. Điều kiện là bạn chịu nhận sự giúp đỡ và không tự đốt cầu trong lúc nóng.]] },
}},
{ tab = "TIỀN · NGHIỆP", items = {
{ t = "Tài bạch · Dần · Vô chính diệu", s = 0.6, body = [[Được: cung không có chính tinh nên mượn sao cung đối diện: Thiên Đồng, Thiên Lương có Hóa Lộc và Thiên Mã. Tiền đến từ dịch vụ, tư vấn, chăm sóc người khác, công việc phải di chuyển hay đổi môi trường. Tam hợp có Cự Môn: lời nói, chữ nghĩa ra tiền.

Mất: Triệt đóng ngay tại cung, Tuần đóng ở cung chiếu về, tức Hóa Lộc bị chặn hai lớp. Kèm Bạch Hổ, Tiểu Hao: hao vặt liên tục.

Cân lại: tiền có đến, nhưng trước khoảng 30 tuổi thì "vào rồi ra" (Triệt mạnh ở tuổi trẻ). Sau đó lực Triệt giảm, Hóa Lộc phát huy dần. Đây không phải lá số phát nhanh bằng tiền, mà là lá số tiền tích từ đều đặn.

Nên làm: trích tự động một phần thu nhập ngay ngày nhận lương; không đứng ra cho vay hay bảo lãnh.]] },
{ t = "Quan lộc · Tuất · Thái Dương hãm", s = -4.0, body = [[Cung yếu nhất lá số.

Được: Long Trì, Hoa Cái (thẩm mỹ, chữ nghĩa, tư duy riêng), Thiên Quan, Thiên Y, Thiên Thọ (có người trên che chở ở thời điểm quyết định).

Mất: Mặt Trời lặn ở Tuất (làm nhiều, được thấy ít) gặp Đà La, Linh Tinh, Thiên Riêu, Quan Phù, Quan Phủ, Địa Võng. Dễ gặp chậm trễ, giấy tờ, va chạm với cấp trên hay quy định, công sức bị người khác nhận.

Cân lại: điểm thấp nói về tuổi trẻ và môi trường công sở nhiều tầng. Đại vận 42–51 rơi đúng vào cung này với Thái Dương Hóa Lộc, nên đó là giai đoạn danh tiếng nở muộn. Trước đó, bạn hợp vai "hậu trường mạnh": người làm ra nội dung, chiến lược, phân tích, hơn là người đứng mũi chịu sào ở tổ chức cứng.]] },
{ t = "Nghề hợp và nghề nên tránh", body = [[Hợp (dùng Cự Môn + Thiên Cơ + Hoa Cái):
• Viết, sáng tạo nội dung, biên tập, truyền thông, marketing (đúng hướng bạn đang làm).
• Phân tích, nghiên cứu, dữ liệu, chiến lược.
• Tư vấn, đào tạo, giảng dạy, pháp chế.
• Công việc tự do hoặc dự án có quyền tự quyết.

Nên cẩn thận:
• Vị trí phải chiều lòng cấp trên liên tục, nhiều tầng duyệt (Quan Phù, Quan Phủ).
• Bán hàng thuần áp chỉ tiêu, đối đầu khách (dễ cháy vì Hỏa Tinh).
• Kinh doanh vốn lớn trước 32 tuổi.]] },
{ t = "Điền trạch · Dậu · Vũ Khúc Hóa Kỵ, Thất Sát", s = 1.5, body = [[Được: Vũ Khúc là sao tài, có khả năng tích sản, mua nhà đất; tam phương có Tử Vi, Tả Hữu, Khoa Quyền và Thiên Phủ chiếu về nên lực đỡ rất mạnh.

Mất: Vũ Khúc Hóa Kỵ và Thất Sát hãm: nhà cửa đến qua vay nợ, giấy tờ rối, sửa chữa tốn kém.

Cân lại: Tuần đóng tại cung, nên cả cái tốt lẫn cái xấu đều đến chậm và nhẹ đi. Nhà đất là chuyện từ 32 tuổi trở đi (đại vận ở chính cung này), và đó là lúc "kiếm và mất đá nhau" rõ nhất (xem tab ĐẠI VẬN).]] },
}},
{ tab = "TÌNH · NHÀ", items = {
{ t = "Phu thê · Thìn · Thái Âm hãm (cũng là cung Thân)", s = -2.4, body = [[Người bạn đời: dịu dàng, tinh tế, sống nội tâm, có khi lạnh hoặc thất thường; có thể làm nghề liên quan nhà cửa, tài chính, chăm sóc hoặc làm ca đêm.

Được: tam hợp có Thiên Đồng, Thiên Lương, Hóa Lộc: người bạn đời có phúc, hiền, về lâu dài mang lại an ổn và tiền. Giải Thần, Địa Giải giúp hai người hàn gắn được sau va chạm.

Mất: Địa Kiếp, Quả Tú, Thiên La, Điếu Khách: thời trẻ tình duyên trắc trở, chia tay, cô đơn giữa hai người. Đối diện là Thái Dương hãm với Đà La, Linh Tinh: hay xung khắc về công việc và thời gian dành cho nhau.

Cân lại: kết hôn sau khoảng 28–30 tuổi bền hơn. Vì Thân cư ở đây, chọn đúng người là quyết định lớn nhất đời bạn, ảnh hưởng hơn cả chọn nghề.]] },
{ t = "Tử tức · Mão · Thiên Phủ, Triệt", s = 1.3, body = [[Được: Thiên Phủ cùng Thiên Khôi, Thiên Đức, Phúc Đức, Ân Quang, Thiên Hỉ: con cái hiền, có phúc, gặp người nâng đỡ.

Mất: Triệt đóng tại cung, Thiên Phủ chỉ ở mức bình hòa: con muộn hoặc ít, giai đoạn đầu nuôi con vất vả.

Cân lại: tốt mà chậm. Con là nguồn vui về sau.]] },
{ t = "Phụ mẫu · Mùi · Thiên Tướng", s = 4.5, body = [[Được: Thiên Tướng đắc địa với Quốc Ấn, Phong Cáo; đối diện là Tử Vi, Tả Hữu, Khoa Quyền. Cha mẹ đàng hoàng, trọng danh dự, là chỗ dựa thật.

Mất: Thiên Không, Bệnh Phù: có giai đoạn cha mẹ hao tài hoặc sức khỏe, hoặc khoảng cách quan điểm.

Cân lại: một trong những cung mạnh nhất. Hỏi ý cha mẹ ở các quyết định lớn thường có lợi.]] },
{ t = "Huynh đệ · Tị · Liêm Trinh, Tham Lang hãm", s = 1.9, body = [[Được: Văn Xương, Thiên Việt, Thiên Giải: anh em, đồng nghiệp ngang hàng có người giỏi chữ, giúp được việc giấy tờ.

Mất: Liêm Tham hãm, Phi Liêm, Phá Toái: tính khí mạnh, ham vui, tiêu xài; dễ có hiểu lầm vì tiền hoặc chuyện riêng tư.

Cân lại: khá. Đại vận hiện tại cho Tham Lang Hóa Lộc ở đây: bạn bè, đồng nghiệp ngang hàng đang là nguồn cơ hội của bạn trong mấy năm này.]] },
{ t = "Nô bộc · Hợi · Lộc Tồn", s = 1.4, body = [[Được: Lộc Tồn, Thiên Quý, Nguyệt Đức: có bạn tốt, cộng sự mang lợi.

Mất: không chính tinh, mượn Liêm Tham hãm; thêm Kiếp Sát, Lưu Hà, Thiên Thương: có người lợi dụng, nhất là về tiền.

Cân lại: tiền của bạn có xu hướng chảy sang tay bạn bè (Lộc Tồn nằm ở Nô chứ không ở Tài). Giúp bằng công sức thì được, cho vay hay góp vốn thì nên có giấy tờ rõ.]] },
}},
{ tab = "SỨC KHỎE · PHÚC", items = {
{ t = "Tật ách · Sửu · Tử Vi, Phá Quân", s = 5.0, body = [[Cung cứu giải mạnh nhất lá số (điểm +6,3, ở đây ghi tối đa +5).

Được: Tử Vi, Tả Phù, Hữu Bật, Hóa Khoa, Hóa Quyền, Long Đức, Thanh Long. Khi ốm hay gặp nạn, bạn gặp người giỏi, giải được.

Cần để ý: Phá Quân ở Tật thường gắn với tiêu hóa, tiết niệu, răng; Tử Vi với tỳ vị. Vì Mệnh nhiều Hỏa, căng thẳng của bạn thường hiện ra cơ thể (dạ dày, ngủ kém) trước khi bạn nhận ra mình đang stress.

Nên làm: khám định kỳ, ăn ngủ đúng giờ. Đây chỉ là gợi ý để chú ý, không phải chẩn đoán.]] },
{ t = "Phúc đức · Thân · Thiên Đồng, Thiên Lương, Hóa Lộc", s = 2.6, body = [[Được: phúc dày, tinh thần lạc quan, hay gặp may vào lúc gần như hết đường. Thiên Mã: phúc đến khi bạn chịu di chuyển, đổi môi trường.

Mất: Tuần làm phúc đến chậm; Cô Thần: bên trong có góc cô độc, ít ai thật sự hiểu bạn. Tang Môn, Đại Hao: phúc có lúc phải trả bằng hao tài.

Cân lại: tốt. Đây cũng là cung của đại vận hiện tại (2023–2032), nên bạn đang sống trong mười năm được phúc che nhiều nhất.]] },
{ t = "Thiên di · Tí · Thiên Cơ, Kình Dương", s = -1.0, body = [[Được: Thiên Cơ đắc địa, Tam Thai, Thiên Tài: ra ngoài nhanh nhạy, xoay xở giỏi, học nhanh môi trường mới.

Mất: Kình Dương hãm, Tuế Phá, Thiên Khốc, Thiên Hư: hay va chạm, tranh cãi ở ngoài; dễ có tai nạn nhỏ do vội.

Cân lại: hơi yếu. Đi xa có lợi về kinh nghiệm hơn là về tiền. Khi đi đường, làm việc với người lạ: chậm lại một nhịp.]] },
}},
{ tab = "ĐẠI VẬN", items = {
{ t = "Cách đọc đại vận", body = [[Mỗi đại vận kéo dài 10 năm (tuổi âm). Mỗi vận có Tứ Hóa riêng (Lộc, Quyền, Khoa, Kỵ) theo can của cung. Điểm dưới đây là điểm của cung đại vận sau khi cộng Tứ Hóa của vận đó. Mỗi vận được tách thành phần Được, phần Mất, rồi cân xem bên nào thắng.]] },
{ t = "2–21 tuổi (2003–2022) · đã qua", body = [[2–11 (cung Mệnh): tuổi thơ năng động, hay bị la vì nói nhiều, cãi lý.
12–21 (Phụ mẫu, điểm +4,5): được cha mẹ đỡ, nhưng vận này có Cự Môn Hóa Kỵ vào Mệnh: tuổi học trò hay bị hiểu lầm vì lời nói, áp lực thi cử, tranh cãi.

Nếu hai điều này đúng với bạn, các phần sau đáng tin hơn.]] },
{ t = "22–31 tuổi (2023–2032) · Phúc đức · HIỆN TẠI", s = 2.4, body = [[Được: vận đẹp nhất nửa đầu đời. Thiên Đồng, Thiên Lương Hóa Lộc, Thiên Mã: có người đỡ, có cơ hội đổi chỗ, đổi nghề, đi xa. Tham Lang Hóa Lộc ở Huynh đệ: cơ hội đến từ bạn bè, đồng nghiệp. Thái Âm Hóa Quyền ở cung Thân: bạn mạnh lên về cảm xúc, chuyện tình cảm rõ ràng hơn.

Mất: Thiên Cơ Hóa Kỵ ở Thiên di (tam hợp của vận): tính toán sai, đổi ý nhiều, va chạm khi ra ngoài; Kình Dương làm việc này căng hơn.

Cân lại: được nhiều hơn mất, khoảng 70/30. Cái mất chủ yếu là sai do vội và nghĩ quá nhiều, không phải xui. Vận này nên học, tích kỹ năng, xây quan hệ hơn là liều tiền lớn.]] },
{ t = "32–41 tuổi (2033–2042) · Điền trạch", s = 1.6, body = [[Đây đúng là vận "kiếm và mất đá nhau" mà bạn hỏi.

Được: Vũ Khúc Hóa Lộc của vận vào chính cung: tiền lớn, nhà đất, tích sản. Tham Lang Hóa Quyền, Thiên Lương Hóa Khoa: tham vọng và uy tín đều lên.

Mất: Vũ Khúc vốn đã Hóa Kỵ từ gốc, nay thêm Văn Khúc Hóa Kỵ của vận cũng vào cung này. Ba Hóa chồng nhau: tiền vào mạnh nhưng nợ vay, hợp đồng, giấy tờ cũng nhiều.

Cân lại: điểm gần như không đổi so với gốc (Lộc +, Kỵ −, triệt tiêu), nên kết quả phụ thuộc gần như hoàn toàn vào kỷ luật. Tam phương có Tử Vi, Tả Hữu, Khoa Quyền đỡ rất mạnh: nếu đọc kỹ hợp đồng, không vay quá sức, bạn giữ được phần lớn. Nếu chạy theo cơ hội, tiền vào bao nhiêu ra bấy nhiêu.]] },
{ t = "42–51 tuổi (2043–2052) · Quan lộc", s = -2.0, body = [[Được: Thái Dương Hóa Lộc vào cung Quan, Thái Âm Hóa Khoa vào cung Thân: cách Nhật Nguyệt phản bối gặp Lộc Khoa, sự nghiệp và danh tiếng nở muộn. Vũ Khúc Hóa Quyền ở Điền: tài sản vững.

Mất: Thiên Đồng Hóa Kỵ vào Phúc đức: tinh thần mệt, ít thời gian hưởng thụ, phúc hao vì lo toan.

Cân lại: cung gốc yếu nhất (−4,0) được nâng lên −2,0. Không phải vận dễ, nhưng đây là lúc công sức nhiều năm được ghi nhận. Đánh đổi bằng sức khỏe tinh thần.]] },
{ t = "52–61 tuổi (2053–2062) · Nô bộc", s = 0.7, body = [[Được: Cự Môn Hóa Lộc vào Mệnh: lời nói, uy tín ra tiền; Thái Dương Hóa Quyền ở Quan: vẫn có tiếng nói trong nghề.
Mất: Văn Xương Hóa Kỵ ở Huynh đệ: mâu thuẫn, giấy tờ với anh em, đồng nghiệp.
Cân lại: khá ổn, sống nhờ quan hệ và danh tiếng đã gây dựng.]] },
{ t = "62–71 tuổi (2063–2072) · Thiên di", s = -0.7, body = [[Đi lại nhiều, tiếp tục bận. Tứ Hóa giống gốc: Thiên Lương Hóa Lộc ở Phúc, Tử Vi Hóa Quyền và Tả Phù Hóa Khoa ở Tật (sức khỏe có người lo), Vũ Khúc Hóa Kỵ ở Điền (để ý nhà cửa, thừa kế).]] },
}},
{ tab = "2026 · 2027", items = {
{ t = "Phần còn lại của Bính Ngọ (tới Tết, 6/2/2027) · 25 tuổi", s = -2.6, body = [[Năm tuổi: Thái Tuế của năm về đúng cung Mệnh, lại thêm Kình Dương của năm cũng vào Mệnh. Tiểu hạn nằm ở Thìn (Phu thê, cung Thân), gặp Đà La của năm và Địa Kiếp gốc.

Được: Thiên Đồng Hóa Lộc và Thiên Mã của năm cùng vào cung đại vận (Phúc đức): có cơ hội đổi việc, đi lại, nguồn thu phụ. Thiên Cơ Hóa Quyền ở Thiên di: ra ngoài có tiếng nói.

Mất: Mệnh có Hỏa Tinh, Thiên Hình, nay thêm Kình Dương: dễ cãi nhau, nóng, va chạm, đứt tay va quệt. Tiểu hạn ở cung tình cảm: chuyện tình hoặc tâm trạng trì trệ, có khúc mắc khó nói. Liêm Trinh Hóa Kỵ ở Huynh đệ: mâu thuẫn với đồng nghiệp, bạn bè.

Cân lại: năm ồn hơn là năm xấu. Mấy tháng cuối năm âm: tránh tranh luận công khai, tránh ký kết khi đang bực.]] },
{ t = "Đinh Mùi 2027 · 26 tuổi", s = 1.1, body = [[Tiểu hạn ở Tị (Huynh đệ), Thái Tuế ở Mùi (Phụ mẫu).

Được: Thái Âm Hóa Lộc vào cung Thân/Phu thê, chính cung yếu của bạn được tiếp lộc: tình cảm khởi sắc, có thể có người mới hoặc quan hệ tiến một bước, tiền liên quan nhà cửa thuận. Thiên Đồng Hóa Quyền ở Phúc (cung đại vận): bạn chủ động hơn. Thiên Cơ Hóa Khoa ở Thiên di: được ghi nhận khi ra ngoài. Lộc Tồn của năm vào Mệnh. Thiên Mã vào tiểu hạn: năm đi lại, đổi chỗ.

Mất: Cự Môn Hóa Kỵ vào thẳng Mệnh. Lời nói gây hiểu lầm, thị phi, có thể đụng chuyện giấy tờ. Tiểu hạn có Liêm Tham hãm cùng Đà La của năm: dễ ham vui, chi tiêu, rắc rối tình cảm ngoài luồng.

Cân lại: tốt hơn 2026. Mệnh vừa có Lộc Tồn vừa có Hóa Kỵ: lời nói kiếm được tiền và cũng gây chuyện. Chọn dùng nó trên giấy (viết, trình bày có chuẩn bị) thay vì ở chỗ đông người.]] },
{ t = "Tóm gọn hai năm", body = [[• 2026 (đến Tết): giữ miệng, giữ bình tĩnh, nhận cơ hội đổi môi trường nếu đến.
• 2027: năm tình cảm và tự tin lên; năm nên viết, xuất bản, làm sản phẩm mang tên mình; cẩn thận giấy tờ, cam kết miệng và chi tiêu cùng bạn bè.]] },
}},
{ tab = "BẢNG ĐIỂM", items = {
{ t = "12 cung (điểm chế hóa, cách tính của Claude)", body = [[Mệnh −2,5 · Phụ mẫu +4,5 · Phúc đức +2,6 · Điền trạch +1,5
Quan lộc −4,0 · Nô bộc +1,4 · Thiên di −1,0 · Tật ách +6,3
Tài bạch +0,6 · Tử tức +1,3 · Phu thê/Thân −2,4 · Huynh đệ +1,9

Mức: ≥ +3 mạnh · +1 đến +3 khá · −1 đến +1 trung bình · −3 đến −1 yếu · dưới −3 rất yếu.]] },
{ t = "Cách tính", body = [[1. Chính tinh theo độ sáng: Miếu +2, Vượng +1,5, Đắc +1, Bình +0,3, Hãm −1.
2. Cát tinh cộng: Hóa Lộc +1,5, Lộc Tồn +1,2, Hóa Quyền/Khoa +1, Tả Hữu, Xương Khúc, Khôi Việt +0,8 (hãm chỉ tính 1/4), sao nhỏ +0,2 đến +0,4.
3. Sát tinh trừ: Không Kiếp −1,8, Hóa Kỵ −1,8, Kình Đà Hỏa Linh −1,5 (đắc địa chỉ −0,6), Thiên Hình −0,9, sao nhỏ −0,2 đến −0,6.
4. Chế hóa: mỗi sao giải (Thiên Giải, Địa Giải, Giải Thần, Thiên Đức, Nguyệt Đức, Long Đức, Phúc Đức) giảm 15% phần sát, tối đa 50%.
5. Tuần nhân hệ số 0,75, Triệt 0,6 cho cả tốt lẫn xấu; cung không chính tinh gặp Tuần/Triệt được +0,5.
6. Điểm cung = bản cung + 0,5 × cung đối diện + 0,3 × mỗi cung tam hợp.

Đây là cách lượng hóa tôi tự đặt để so nặng nhẹ, không phải điểm huyền khí của Tử Vi Cổ Học.]] },
{ t = "Dữ liệu lá số", body = [[Nam, sinh giờ Tị, ngày 24 tháng 10 năm Nhâm Ngọ (âm lịch), khoảng 28/11/2002 dương lịch. Dương Nam, mệnh Dương Liễu Mộc, Thủy Nhị Cục. Mệnh ở Ngọ, Thân cư Phu thê ở Thìn. Mệnh chủ Phá Quân, Thân chủ Hỏa Tinh.

Tứ Hóa gốc (can Nhâm): Thiên Lương Hóa Lộc (Thân), Tử Vi Hóa Quyền (Sửu), Tả Phù Hóa Khoa (Sửu), Vũ Khúc Hóa Kỵ (Dậu). Tuần ở Thân, Dậu; Triệt ở Dần, Mão.]] },
}},
}

-- ===== Bản đồ sao (Placidus, 28/11/2002 10:10 Bắc Giang) + Thần số học (TRẦN ĐỨC HOAN) =====
local DATA2 = {
{ tab = "TỔNG QUAN", items = {
{ t = "Bức tranh trong một câu", body = [[Một người đi tìm sự thật và muốn nói nó ra cho đông người nghe, nhưng bên trong luôn tự chấm điểm mình khắt khe.

Bản đồ sao và thần số học ở đây nói khá giống nhau, và giống luôn cả lá số tử vi: đầu óc sắc, lời nói có sức nặng, khác người, nội tâm nhạy và tự phê bình. Chỗ mạnh nhất cũng là chỗ dễ vấp nhất.]] },
{ t = "Bộ ba chính của bản đồ sao", body = [[• Mặt Trời Nhân Mã, nhà 10: sống để đi tìm ý nghĩa, tự do, tầm nhìn; bản ngã gắn với sự nghiệp và hình ảnh trước xã hội.
• Mặt Trăng Xử Nữ, nhà 8: cảm xúc phân tích, chu toàn, hay lo; xử lý cảm xúc ở tầng sâu, kín, ít khi nói ra.
• Cung Mọc Bảo Bình (0°10'), có Thiên Vương và Hải Vương ở nhà 1: bề ngoài độc lập, khác thường, lý tưởng, khó đoán.

Lưu ý: Cung Mọc chỉ vừa qua ranh giới Ma Kết. Nếu giờ sinh sớm hơn vài phút, Cung Mọc là Ma Kết (nghiêm, thực tế hơn). Giờ 10:10 thuộc giờ Tị, khớp với lá số tử vi.]] },
{ t = "Các con số chính (thần số học)", body = [[• Đường đời 7 (từ tổng 16/7): người tìm tòi, cần hiểu bản chất, cần thời gian một mình.
• Sứ mệnh 11 và Linh hồn 11 (hai số Master): trực giác, truyền cảm hứng, nhạy cảm cao, dễ căng thẳng thần kinh.
• Nhân cách 9: người ngoài thấy bạn rộng lượng, có lý tưởng.
• Thái độ 3: phản ứng đầu tiên là nói, đùa, thể hiện.
• Ngày sinh 1: tự lập, muốn làm theo cách mình.
• Trưởng thành 9 (từ khoảng 40 tuổi): hướng tới phục vụ, cho đi.

Tôi tự tính lại các số này và khớp với báo cáo bạn gửi. Báo cáo còn ghi nợ nghiệp 13; tôi chỉ tìm ra được nợ 16 (ở Đường đời).]] },
{ t = "Ba điểm cả ba hệ thống cùng nói", body = [[1. Lời nói và tư duy sắc: Cự Môn ở Mệnh (tử vi) · Sao Thủy trùng Diêm Vương (sao) · Sứ mệnh 11 (số).
2. Nội tâm nhạy, tự phê bình: Thái Âm hãm ở cung Thân · Mặt Trăng Xử Nữ vuông góc Mặt Trời, Sao Thủy, Diêm Vương · Đường đời 7.
3. Khác người, nhiều ý tưởng: Địa Không ở Mệnh · Bảo Bình mọc có Thiên Vương, Hải Vương · hai số 11.

Khi ba hệ thống độc lập cùng chỉ một hướng, đó là phần đáng tin nhất để bạn soi lại mình. Xem chi tiết ở tab ĐỐI CHIẾU.]] },
}},
{ tab = "TÍNH CÁCH", items = {
{ t = "Đầu óc: Nhân Mã + Diêm Vương", body = [[Mặt Trời và Sao Thủy cùng ở Nhân Mã: nghĩ lớn, thích triết lý, nói thẳng, ghét bị gò bó. Sao Thủy trùng Diêm Vương (cách 3°30'): suy nghĩ đào sâu, đọc được động cơ ẩn của người khác, lời nói có sức nặng, khi tranh luận thì không buông.

Mặt trái: dễ thành "người giảng chân lý", nghe để phản bác hơn là để hiểu. Sao Thủy lục hợp Hải Vương và có góc ngũ phân với Thiên Vương: ý tưởng lạ, trực giác tốt, viết hay.]] },
{ t = "Cảm xúc: Mặt Trăng Xử Nữ bị vuông góc", body = [[Mặt Trăng vuông góc với Mặt Trời, Sao Thủy, Diêm Vương và Nút Bắc. Bên ngoài (Nhân Mã) muốn bay; bên trong (Xử Nữ) lo từng chi tiết và tự hỏi "mình đã đủ tốt chưa".

Kết quả: bạn có thể nói rất tự tin rồi về nhà soi lại từng câu mình đã nói. Căng thẳng thần kinh hay dồn vào cơ thể (ngủ, tiêu hóa), khớp với gợi ý về sức khỏe trong lá số tử vi.

Cách cân lại: viết ra. Mặt Trăng Xử Nữ dịu đi khi được sắp xếp, ghi chép, làm việc tỉ mỉ có mục đích.]] },
{ t = "Bề ngoài: Bảo Bình mọc", body = [[Thiên Vương, Hải Vương ở nhà 1: người ta thấy bạn độc lập, có gu riêng, đôi khi xa cách hoặc "ở trên mây". Sao Kim và Sao Hỏa vuông góc với Cung Mọc: sức hút mạnh, nhưng tạo cảm giác khó gần lúc đầu.

Thần số: Nhân cách 9 (rộng lượng, lý tưởng) và Thái độ 3 (vui, nói nhiều) làm mềm hình ảnh đó: lần đầu gặp thì vui vẻ, nhưng càng gần càng thấy bạn có một vùng riêng không cho ai vào.]] },
{ t = "Đường đời 7 với hai số 11", body = [[Số 7 cần im lặng, chiêm nghiệm, tìm câu trả lời một mình. Số 11 cần được nói ra, chia sẻ, truyền cảm hứng. Đây là cặp mâu thuẫn trung tâm của bạn: muốn ở một mình để hiểu, rồi muốn ra sân khấu để nói.

Trong thần số học, đây không phải lỗi mà là nhịp: thu vào, rồi phát ra. Khi bỏ mất nhịp thu vào, bạn nói nhiều mà rỗng; khi bỏ mất nhịp phát ra, bạn hiểu nhiều mà cô độc.]] },
}},
{ tab = "TIỀN · NGHIỆP", items = {
{ t = "Sự nghiệp là trung tâm (Mặt Trời nhà 10)", body = [[Mặt Trời ở nhà 10, Thiên Đỉnh (MC) ở Bọ Cạp: bạn cần một sự nghiệp có danh, có chiều sâu; làm việc vô danh lâu sẽ thấy mất mình. Bọ Cạp ở MC hợp với nghề nghiên cứu, phân tích, đào sâu, xử lý chuyện người khác né tránh, quyền lực ở hậu trường.

MC lục hợp Mặt Trăng: công việc liên quan con người, cảm xúc công chúng (nội dung, truyền thông) là đất tốt. MC vuông góc Mộc Tinh và Hải Vương: dễ kỳ vọng quá cao hoặc mơ hồ về hướng đi; cần mục tiêu đo được.]] },
{ t = "Tay nghề: Thổ Tinh nghịch hành ở nhà 5", body = [[Thổ Tinh ở Song Tử, nhà 5, tam hợp Sao Kim, Sao Hỏa và Thiên Vương: khả năng sáng tạo có kỷ luật, đặc biệt với chữ và ý tưởng. Bạn hợp với nghề làm ra sản phẩm sáng tạo có cấu trúc: viết, biên tập, dựng nội dung, thiết kế thông tin.

Nghịch hành: thường tự tin về tài sáng tạo muộn, hay nghi ngờ khả năng của mình lúc trẻ.]] },
{ t = "Tiền bạc", body = [[Nhà 2 bắt đầu ở Song Ngư, chủ tinh Hải Vương nằm ở nhà 1, Mộc Tinh đồng chủ ở nhà 7. Tiền đến qua hình ảnh cá nhân, ý tưởng, và qua đối tác, khách hàng. Mặt trái: Hải Vương làm tiền khó nắm, dễ chi theo cảm hứng, dễ tin người.

Thần số: ngày sinh 1 và chu kỳ thứ hai (30–56 tuổi) mang số 1, rất hợp tự làm chủ hoặc làm dự án riêng từ khoảng 30 tuổi. Đỉnh cao thứ ba (39–47 tuổi) là số 8: số của tiền bạc và quản lý, khớp với đại vận tài sản 32–41 bên tử vi.]] },
}},
{ tab = "TÌNH CẢM", items = {
{ t = "Sao Kim Bọ Cạp trùng Sao Hỏa", body = [[Sao Kim ở Bọ Cạp (0°58') trùng Sao Hỏa ở Thiên Bình, cùng nhà 9: yêu mãnh liệt, sâu, muốn gắn bó toàn phần; dễ ghen, khó tha thứ khi bị phản bội. Hay bị hút bởi người khác văn hóa, khác nền tảng, hoặc gặp qua học hành, du lịch, mạng.

Sao Kim vuông góc Cung Mọc và Hải Vương: tình cảm dễ lý tưởng hóa người kia rồi vỡ mộng. Sao Kim tam hợp Thổ Tinh: khi đã cam kết thì nghiêm túc, bền.]] },
{ t = "Mộc Tinh ở nhà 7", body = [[Mộc Tinh Sư Tử ở nhà 7 (nhà của hôn nhân, đối tác): người bạn đời rộng lượng, nổi bật, mang lại may mắn và mở rộng thế giới của bạn. Đây là điểm sáng.

Mộc Tinh đối đỉnh Thiên Vương và Hải Vương ở nhà 1: giằng co giữa nhu cầu tự do của bạn và nhu cầu gắn kết. Bạn cần một người cho bạn khoảng riêng.

Tử vi cũng nói tương tự: Phu thê thời trẻ trắc trở, nhưng tam hợp có Lộc, người bạn đời về lâu dài mang phúc.]] },
{ t = "Theo thần số", body = [[Linh hồn 11: điều bạn thật sự cần trong tình yêu là kết nối tinh thần, được hiểu, không phải chỉ vui vẻ. Đường đời 7: cần thời gian riêng ngay cả khi đang yêu.

Chu kỳ đầu đời (đến 29 tuổi) mang số 11/2: nhạy cảm, dễ tổn thương, muốn gắn bó. Từ 30 tuổi chuyển sang số 1: độc lập hơn; báo cáo cũng lưu ý giai đoạn này dễ căng thẳng với bạn đời nếu không hiểu rõ nhu cầu của mình.]] },
}},
{ tab = "BÀI HỌC", items = {
{ t = "Nút Bắc Song Tử nhà 4", body = [[Nút Nam ở Nhân Mã nhà 10 (cái quen): rao giảng, có câu trả lời sẵn, sống vì hình ảnh bên ngoài. Nút Bắc ở Song Tử nhà 4 (hướng cần đi): hỏi nhiều hơn, nghe nhiều hơn, chấp nhận nhiều góc nhìn; xây gốc rễ, nhà, gia đình.

Nút Bắc tam hợp Hải Vương: trực giác giúp bạn đi đúng hướng này. Nút vuông góc Mặt Trăng: phải học cách chăm sóc cảm xúc của chính mình.]] },
{ t = "Nợ nghiệp 16 và bài học số 7", body = [[Nợ nghiệp 16 trong thần số học nói về cái tôi: những gì dựng trên kiêu hãnh sẽ bị đổ để xây lại trên nền thật hơn. Đi cùng Đường đời 7, bài học là khiêm tốn trí tuệ: hiểu nhiều không có nghĩa là đúng.

Tên của bạn thiếu số 7, trùng với Đường đời 7: bạn sinh ra để học sự chiêm nghiệm, nhưng bản năng (tên gọi) lại thiên về hành động, thể hiện. Phải chủ động tập: đọc sâu, thiền, đi bộ một mình.]] },
{ t = "Chiron Ma Kết nhà 12 và các thử thách", body = [[Chiron ở Ma Kết nhà 12: vết thương kín về thành tựu và sự công nhận, cảm giác phải chứng minh mình đủ giỏi. Đây cũng là chỗ bạn hiểu và giúp được người khác nhiều nhất.

Thử thách thần số: đầu đời là số 1 (dám đứng riêng mà không cứng đầu), giữa đời là số 3 (nói ít mà chất, đừng phân tán), về sau là số 2 (kiên nhẫn, hợp tác).]] },
}},
{ tab = "CHU KỲ", items = {
{ t = "Các mốc lớn của đời", body = [[• Đến 29 tuổi (2031): Đỉnh cao 3, chu kỳ 11/2. Giai đoạn học, thể hiện, sáng tạo; cảm xúc nhạy.
• Khoảng giữa 2032 (gần 30 tuổi): Thổ Tinh trở về vị trí gốc, tức "lần trưởng thành thứ nhất". Đồng thời thần số đổi chu kỳ (sang số 1) và đổi đỉnh cao (sang số 5).
• 30–38 tuổi: Đỉnh cao 5 (thay đổi, tự do, đi lại).
• 39–47 tuổi: Đỉnh cao 8 (tiền, quyền, quản lý).
• Từ 48 tuổi: Đỉnh cao 6 (gia đình, trách nhiệm); từ 57 tuổi chu kỳ số 4 (bền bỉ, làm việc lâu).

Khớp tử vi: cung Thân phát sau 30; đại vận đổi từ Phúc đức sang Điền trạch năm 32 tuổi (2033). Cả ba hệ thống cùng chỉ khoảng 2031–2033 là bước ngoặt lớn nhất trước 40.]] },
}},
{ tab = "2026 · 2027", items = {
{ t = "Cuối 2026 (đến hết tháng 1/2027)", body = [[Năm cá nhân 2026: số 22/4 (Master xây dựng): năm đặt nền, làm việc nặng, kỷ luật, kết quả chưa thấy ngay.

Chuyển động sao chính (tôi tự tính bằng quỹ đạo gần đúng, sai số dưới 1°):
• Thổ Tinh vuông góc Chiron (11/2026–1/2027): cảm giác "chưa đủ giỏi" trỗi dậy; dễ tự ép mình.
• Thổ Tinh lục hợp Hải Vương và Nút Bắc: kỷ luật giúp ước mơ thành hình; hợp lập kế hoạch dài hạn.
• Mộc Tinh đối đỉnh Thiên Vương gốc: muốn bứt ra, đổi mới đột ngột; cẩn thận quyết định bốc đồng.

Khớp tử vi: phần cuối năm Bính Ngọ là năm tuổi, Kình Dương vào Mệnh. Cả hai hệ cùng khuyên: chậm lại, đừng phản ứng nóng.]] },
{ t = "2027 · năm cá nhân 5", body = [[Số 5: năm thay đổi, đi lại, tự do, cơ hội mới.

• Mộc Tinh trở về vị trí gốc ở nhà 7 (3–5/2027), cùng lúc tam hợp Diêm Vương và được Thổ Tinh tam hợp: đầu năm (âm) là quãng đẹp nhất cho tình cảm, hợp tác, ký kết, gặp người quan trọng.
• Hải Vương tam hợp Mặt Trời (3–11/2027) và Diêm Vương lục hợp Mặt Trời (cả năm): cảm hứng sáng tạo cao, sức ảnh hưởng tăng; hợp làm sản phẩm mang tên mình.
• Thiên Vương đối đỉnh Mặt Trời (4–6/2027, lặp lại cuối năm): thay đổi đột ngột về công việc hoặc hình ảnh bản thân.
• Thiên Vương trùng Nút Bắc nhà 4 (6–12/2027): đổi chỗ ở, chuyện nhà cửa, gia đình.
• Thổ Tinh đối đỉnh Sao Hỏa (6–9/2027): giữa năm dễ bực bội, bị chặn, xung đột. Đây là quãng cần giữ bình tĩnh nhất.

Khớp tử vi 2027: Thái Âm Hóa Lộc vào Phu thê/Thân (tình cảm lên), Cự Môn Hóa Kỵ vào Mệnh (lời nói gây chuyện), Thiên Mã (đi lại). Ba hệ thống trùng nhau rất rõ.]] },
{ t = "Gợi ý theo quý cho 2027", body = [[• Quý 1: chuẩn bị, chốt kế hoạch.
• Quý 2 (tháng 3–5 dương lịch): thời điểm mạnh nhất cho tình cảm, hợp tác, ra mắt dự án.
• Quý 3: chậm lại, tránh tranh cãi và cam kết khi đang bực (Thổ Tinh đối Sao Hỏa, Cự Môn Hóa Kỵ).
• Quý 4: chuyện nhà cửa, gia đình, có thể chuyển chỗ ở.]] },
}},
{ tab = "ĐỐI CHIẾU", items = {
{ t = "Chỗ cả ba hệ thống trùng nhau", body = [[• Lời nói, tư duy sắc: Cự Môn vượng ở Mệnh · Sao Thủy trùng Diêm Vương · Sứ mệnh 11.
• Nóng, dễ va chạm: Hỏa Tinh, Thiên Hình, Kình Dương chiếu Mệnh · Sao Hỏa vuông góc Cung Mọc · Thái độ 3, thử thách số 3.
• Nội tâm nhạy, tự phê: Thái Âm hãm ở Thân · Mặt Trăng Xử Nữ bị vuông góc nhiều · Đường đời 7, Linh hồn 11.
• Khác người: Địa Không ở Mệnh · Bảo Bình mọc, Thiên Vương, Hải Vương nhà 1.
• Con cái muộn: Triệt ở Tử tức · Thổ Tinh ở nhà 5.
• Người bạn đời mang phúc dù tình duyên trẻ trắc trở: tam hợp Lộc của Phu thê · Mộc Tinh nhà 7.
• Bước ngoặt 2031–2033: Thân phát sau 30, đại vận đổi năm 32 · Thổ Tinh trở về · đổi chu kỳ và đỉnh cao thần số.
• 2027 tình cảm mở, lời nói rủi ro: Thái Âm Hóa Lộc, Cự Môn Hóa Kỵ · Mộc Tinh trở về nhà 7, Thổ Tinh đối Sao Hỏa · năm cá nhân 5.]] },
{ t = "Chỗ các hệ thống nói khác nhau", body = [[Sự nghiệp: tử vi cho Quan lộc yếu nhất lá số (Thái Dương hãm), còn bản đồ sao đặt Mặt Trời ở nhà 10, tức sự nghiệp là trung tâm.

Cách hiểu hợp lý: sự nghiệp là thứ quan trọng nhất với bạn (sao), nhưng đường đi tới đó chậm và nhiều va chạm (tử vi). MC vuông góc Mộc Tinh, Hải Vương cũng cho thấy kỳ vọng dễ vượt thực tế. Cả hai cùng gợi ý: thành tựu nghề nghiệp đến muộn, khoảng 40 tuổi trở đi (đại vận Quan lộc 42–51, đỉnh cao 8 từ 39 tuổi).]] },
{ t = "Một lời khuyên chung", body = [[Ba hệ thống, một thông điệp: năng lực của bạn nằm ở cái đầu và cái miệng; rủi ro cũng nằm ở đó. Thu vào trước khi phát ra. Viết trước khi nói. Hỏi trước khi kết luận (đúng bài học Nút Bắc Song Tử).

Tất cả chỉ là công cụ soi chiếu, không có kiểm chứng khoa học. Phần trùng nhau giữa các hệ thống đáng để bạn tự kiểm lại với trải nghiệm thật của mình.]] },
}},
}

local SETS = {
    { name = "TỬ VI", data = DATA, sub = "Nhâm Ngọ · Dương Nam · giờ Tị" },
    { name = "SAO & SỐ", data = DATA2, sub = "28/11/2002 · 10:10 · Bắc Giang" },
}

local BODY_PX, TITLE_PX = 25, 30

local TuVi = InputContainer:extend{
    name = "vn_tuvi",
    covers_fullscreen = true,
    tab = 1,
    page = 1,
    set = 1,
}

-- chia nội dung một tab thành các khối (tiêu đề + đoạn), rồi xếp vào trang 2 cột
function TuVi:layout(cw, ch)
    local blocks = {}
    for _, it in ipairs(SETS[self.set].data[self.tab].items) do
        local paras = {}
        for p in (it.body .. "\n\n"):gmatch("(.-)\n\n") do
            if p:match("%S") then paras[#paras + 1] = p end
        end
        for k, p in ipairs(paras) do
            local b = { text = p, title = (k == 1) and it.t or nil, s = (k == 1) and it.s or nil, first = k == 1 }
            local tb = TextBoxWidget:new{ text = p, face = face(BODY_PX), width = cw - 30, fgcolor = BLACK }
            b.th = tb:getSize().h
            tb:free()
            local h = b.th + 14
            if b.title then
                local tt = TextBoxWidget:new{ text = b.title, face = face(TITLE_PX), width = cw - 30, bold = true, fgcolor = BLACK }
                b.tth = tt:getSize().h
                tt:free()
                h = h + b.tth + 12 + (b.s and 46 or 0) + 10
            end
            b.h = h
            blocks[#blocks + 1] = b
        end
    end
    local pages, cur, col, y = {}, { {}, {} }, 1, 0
    for _, b in ipairs(blocks) do
        local need = b.h + (b.first and y > 0 and 24 or 0)
        if y > 0 and y + need > ch then
            if col == 1 then col, y = 2, 0
            else
                pages[#pages + 1] = cur
                cur, col, y = { {}, {} }, 1, 0
            end
            need = b.h
        end
        b.y = y + ((b.first and y > 0) and 24 or 0)
        table.insert(cur[col], b)
        y = b.y + b.h
    end
    if #cur[1] > 0 then pages[#pages + 1] = cur end
    return pages
end

function TuVi:draw_score(bb, x, y, s)
    local lab = "ĐIỂM " .. fmt(s) .. " · " .. level(s)
    local pw = 300
    bb:paintRoundedRect(x, y, pw, 36, BLACK, 18)
    txt(bb, lab, x + math.floor(pw / 2), y + 6, 20, { center = true, bold = true, color = WHITE })
    -- thanh -5..+5
    local bx, bw = x + pw + 20, 300
    local cy = y + 12
    bb:paintBorder(bx, cy, bw, 14, 2, BLACK, 7)
    local mid = bx + math.floor(bw / 2)
    bb:paintRect(mid - 1, cy - 6, 3, 26, BLACK)
    local v = math.max(-5, math.min(5, s))
    local len = math.floor(math.abs(v) / 5 * (bw / 2 - 4))
    if v >= 0 then bb:paintRect(mid, cy + 3, len, 8, BLACK)
    else bb:paintRect(mid - len, cy + 3, len, 8, GRAY5) end
end

function TuVi:draw_block(bb, x, y, cw, b)
    local yy = y
    if b.title then
        bb:paintRect(x, yy + 4, 8, b.tth - 4, BLACK)
        local tt = TextBoxWidget:new{ text = b.title, face = face(TITLE_PX), width = cw - 30, bold = true, fgcolor = BLACK }
        tt:paintTo(bb, x + 22, yy)
        tt:free()
        yy = yy + b.tth + 12
        if b.s then
            self:draw_score(bb, x + 22, yy, b.s)
            yy = yy + 46
        end
        yy = yy + 10
    end
    local tb = TextBoxWidget:new{ text = b.text, face = face(BODY_PX), width = cw - 30, fgcolor = BLACK }
    tb:paintTo(bb, x + 22, yy)
    tb:free()
end

function TuVi:paintTo(bb, x, y)
    local W, H = self.dimen.w, self.dimen.h
    self.hits = {}
    bb:paintRect(x, y, W, H, WHITE)
    local ok, err = pcall(function()
        local mx = 36
        bb:paintRoundedRect(mx, 30, W - 2 * mx, 84, BLACK, 24)
        local D = SETS[self.set].data
        txt(bb, SETS[self.set].name .. " · " .. D[self.tab].tab, mx + 34, 42, 44, { bold = true, color = WHITE })
        txt(bb, SETS[self.set].sub, W - mx - 34, 56, 26, { right = true, color = WHITE })
        -- thanh tab
        local ty, th, gap = 132, 62, 8
        local n = #D
        local tw = math.floor((W - 2 * mx - (n - 1) * gap) / n)
        for i, d in ipairs(D) do
            local tx = mx + (i - 1) * (tw + gap)
            if i == self.tab then
                bb:paintRoundedRect(tx, ty, tw, th, BLACK, 20)
                txt(bb, d.tab, tx + math.floor(tw / 2), ty + 17, 21, { center = true, bold = true, color = WHITE, max_width = tw - 10 })
            else
                bb:paintBorder(tx, ty, tw, th, 3, BLACK, 20)
                txt(bb, d.tab, tx + math.floor(tw / 2), ty + 17, 21, { center = true, bold = true, max_width = tw - 10 })
            end
            self.hits[#self.hits + 1] = { x = tx, y = ty, w = tw, h = th, fn = function()
                self.tab, self.page, self.pages = i, 1, nil
                UIManager:setDirty(self, "full")
            end }
        end
        local top = ty + th + 26
        local bottom = H - 30 - 84 - 22 - 16
        local cgap = 44
        local cw = math.floor((W - 2 * mx - cgap) / 2)
        if not self.pages then self.pages = self:layout(cw, bottom - top) end
        if self.page > #self.pages then self.page = #self.pages end
        if self.page < 1 then self.page = 1 end
        local pg = self.pages[self.page]
        if pg then
            for c = 1, 2 do
                local cx = mx + (c - 1) * (cw + cgap)
                for _, b in ipairs(pg[c]) do self:draw_block(bb, cx, top + b.y, cw, b) end
            end
            bb:paintRect(mx + cw + math.floor(cgap / 2) - 1, top, 2, bottom - top, GRAY5)
        end
        -- chạm nửa trái / phải vùng nội dung để lật trang
        local np = #self.pages
        self.hits[#self.hits + 1] = { x = 0, y = top, w = math.floor(W / 2), h = bottom - top, fn = function() self:flip(-1) end }
        self.hits[#self.hits + 1] = { x = math.floor(W / 2), y = top, w = W - math.floor(W / 2), h = bottom - top, fn = function() self:flip(1) end }
        -- nút
        local list = {
            { "◀ TRANG TRƯỚC", function() self:flip(-1) end, false, 1.4 },
            { "TRANG " .. self.page .. " / " .. np, function() end, false, 1.1 },
            { "TRANG SAU ▶", function() self:flip(1) end, true, 1.4 },
            { "⇄ " .. SETS[self.set % #SETS + 1].name, function()
                self.set = self.set % #SETS + 1
                self.tab, self.page, self.pages = 1, 1, nil
                UIManager:setDirty(self, "full")
            end, true, 1.3 },
            { "THOÁT", function() self:close() end, false, 1 },
        }
        local bh, bgap = 84, 16
        local by = H - 30 - bh - 22
        local totw = 0
        for _, b in ipairs(list) do totw = totw + b[4] end
        local avail = W - 2 * mx - (#list - 1) * bgap
        local bx = mx
        for _, b in ipairs(list) do
            local bw = math.floor(avail * b[4] / totw)
            if b[3] then
                bb:paintRoundedRect(bx, by, bw, bh, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 24, 26, { center = true, bold = true, color = WHITE })
            else
                bb:paintBorder(bx, by, bw, bh, 4, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 24, 26, { center = true, bold = true })
            end
            table.insert(self.hits, 1, { x = bx, y = by, w = bw, h = bh, fn = b[2] })
            bx = bx + bw + bgap
        end
    end)
    if not ok then
        txt(bb, "Lỗi hiển thị: " .. tostring(err), 40, 260, 24, { max_width = W - 80 })
    end
end

function TuVi:flip(d)
    local np = self.pages and #self.pages or 1
    local p = self.page + d
    if p < 1 then
        if self.tab > 1 then self.tab = self.tab - 1; self.pages = nil; self.page = 99 else return end
    elseif p > np then
        if self.tab < #SETS[self.set].data then self.tab = self.tab + 1; self.pages = nil; self.page = 1 else return end
    else
        self.page = p
    end
    UIManager:setDirty(self, "full")
end

function TuVi:onCloseTuVi()
    self:close()
    return true
end

function TuVi:onTap(_, ges)
    local p = ges and ges.pos
    if not p then return true end
    for _, hb in ipairs(self.hits or {}) do
        if p.x >= hb.x and p.x < hb.x + hb.w and p.y >= hb.y and p.y < hb.y + hb.h then
            hb.fn()
            return true
        end
    end
    return true
end

function TuVi:onSwipe(_, ges)
    if ges and ges.direction == "west" then self:flip(1) elseif ges and ges.direction == "east" then self:flip(-1) end
    return true
end

function TuVi:close()
    if self.old_rotation ~= nil and self.old_rotation ~= Screen:getRotationMode() then
        Screen:setRotationMode(self.old_rotation)
    end
    UIManager:close(self)
    UIManager:setDirty("all", "full")
    if self.on_close then pcall(self.on_close) end
end

function TuVi:start()
    self.old_rotation = Screen:getRotationMode()
    if self.old_rotation ~= 1 then Screen:setRotationMode(1) end
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
        Swipe = { GestureRange:new{ ges = "swipe", range = self.dimen } },
    }
    self.key_events = { CloseTuVi = { { "Back" } } }
    self.hits = {}
    UIManager:show(self, "full")
end

local M = {}
function M.open(on_close)
    local w = TuVi:new{ on_close = on_close }
    w:start()
    return w
end
return M
