-- Bốc Tarot: màn hình riêng, chạy offline, nạp lười bởi main.lua (dofile)
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
local HISTORY = "/mnt/us/vn_dash/tarot_history.txt"

local function face(px)
    local s = math.floor(px * 100 / Screen:scaleBySize(100) + 0.5)
    if s < 6 then s = 6 end
    return Font:getFace("cfont", s)
end

local function txt(bb, s, x, y, px, opts)
    opts = opts or {}
    local tw = TextWidget:new{
        text = tostring(s),
        face = face(px),
        bold = opts.bold or false,
        fgcolor = opts.color or BLACK,
        max_width = opts.max_width,
        padding = 0,
    }
    local w = tw:getWidth()
    local h = tw:getSize().h
    local px0 = x
    if opts.right then px0 = x - w elseif opts.center then px0 = x - math.floor(w / 2) end
    tw:paintTo(bb, math.floor(px0), math.floor(y))
    tw:free()
    return w, h
end

-- ===== dữ liệu 78 lá =====
local ROMAN = { [0] = "0", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X", "XI", "XII", "XIII", "XIV", "XV", "XVI", "XVII", "XVIII", "XIX", "XX", "XXI" }

local MAJOR = {
    { "Chàng Khờ", "The Fool", "Khởi đầu mới, tự do, liều lĩnh trong sáng, tin vào hành trình.", "Bồng bột, thiếu cân nhắc, sợ bước đi đầu tiên." },
    { "Nhà Ảo Thuật", "The Magician", "Làm chủ nguồn lực, biến ý chí thành hành động.", "Thao túng, tài năng bị lãng phí, thiếu tập trung." },
    { "Nữ Tư Tế", "The High Priestess", "Trực giác, bí ẩn, lắng nghe tiếng nói bên trong.", "Bỏ qua trực giác, có điều bị che giấu." },
    { "Hoàng Hậu", "The Empress", "Sung túc, nuôi dưỡng, sáng tạo, vẻ đẹp.", "Phụ thuộc, kiệt sức vì chăm lo, bế tắc sáng tạo." },
    { "Hoàng Đế", "The Emperor", "Quyền lực, trật tự, cấu trúc, trách nhiệm.", "Cứng nhắc, độc đoán, lạm quyền." },
    { "Giáo Hoàng", "The Hierophant", "Truyền thống, người dẫn đường, chuẩn mực chung.", "Phá lệ, nghi ngờ khuôn mẫu, tự đi đường riêng." },
    { "Người Tình", "The Lovers", "Tình yêu, hòa hợp, lựa chọn theo giá trị của mình.", "Lệch pha, lựa chọn sai, thiếu cam kết." },
    { "Cỗ Xe", "The Chariot", "Ý chí chiến thắng, quyết tâm, tiến lên.", "Mất kiểm soát, lạc hướng, hung hăng." },
    { "Sức Mạnh", "Strength", "Can đảm mềm mỏng, kiên nhẫn, làm chủ bản thân.", "Tự nghi ngờ, yếu lòng, nóng nảy." },
    { "Ẩn Sĩ", "The Hermit", "Tĩnh lặng, tìm câu trả lời bên trong, chiêm nghiệm.", "Cô lập quá mức, từ chối lời khuyên." },
    { "Bánh Xe Số Phận", "Wheel of Fortune", "Vận may xoay chuyển, chu kỳ mới, định mệnh.", "Xui rủi tạm thời, chống lại thay đổi." },
    { "Công Lý", "Justice", "Công bằng, sự thật, hệ quả của hành động.", "Bất công, né trách nhiệm, thiếu trung thực." },
    { "Người Treo Ngược", "The Hanged Man", "Buông bỏ, nhìn từ góc khác, biết chờ đợi.", "Trì hoãn vô ích, hy sinh không cần thiết." },
    { "Thần Chết", "Death", "Kết thúc để tái sinh, chuyển hóa sâu sắc.", "Bám víu quá khứ, chống lại đổi thay." },
    { "Tiết Chế", "Temperance", "Cân bằng, kiên nhẫn, hòa hợp, trung dung.", "Mất cân bằng, cực đoan, vội vàng." },
    { "Ác Quỷ", "The Devil", "Ràng buộc, cám dỗ, ham muốn, thói quen khó bỏ.", "Thoát khỏi ràng buộc, nhận ra xiềng xích." },
    { "Tòa Tháp", "The Tower", "Biến cố đột ngột, sụp đổ điều giả tạo, thức tỉnh.", "Né tránh biến cố, sụp đổ âm ỉ." },
    { "Ngôi Sao", "The Star", "Hy vọng, chữa lành, cảm hứng, niềm tin.", "Mất niềm tin, mệt mỏi, hy vọng mờ nhạt." },
    { "Mặt Trăng", "The Moon", "Ảo giác, lo âu, trực giác, điều chưa rõ ràng.", "Sự thật sáng tỏ, bớt sợ hãi, hiểu lầm tan." },
    { "Mặt Trời", "The Sun", "Niềm vui, thành công, năng lượng sống.", "Niềm vui bị che mờ, lạc quan thái quá." },
    { "Phán Xét", "Judgement", "Thức tỉnh, nhìn lại, gọi tên sứ mệnh.", "Tự phán xét, trốn tránh bài học." },
    { "Thế Giới", "The World", "Hoàn thành, trọn vẹn, đạt đích, mở hành trình mới.", "Chưa khép lại, thiếu chút nữa là xong." },
}

local SUITS = {
    { "Gậy", "Wands", "wands", "hành động, đam mê, sự nghiệp, sáng tạo", "GẬY" },
    { "Cốc", "Cups", "cups", "tình cảm, cảm xúc, các mối quan hệ", "CỐC" },
    { "Kiếm", "Swords", "swords", "tư duy, lời nói, xung đột, quyết định", "KIẾM" },
    { "Tiền", "Pentacles", "pentacles", "tiền bạc, công việc, sức khỏe, vật chất", "TIỀN" },
}

local RANKS = {
    { "A", "Át", "Ace" }, { "2", "Hai", "Two" }, { "3", "Ba", "Three" }, { "4", "Bốn", "Four" },
    { "5", "Năm", "Five" }, { "6", "Sáu", "Six" }, { "7", "Bảy", "Seven" }, { "8", "Tám", "Eight" },
    { "9", "Chín", "Nine" }, { "10", "Mười", "Ten" }, { "P", "Thị Đồng", "Page" },
    { "Kn", "Hiệp Sĩ", "Knight" }, { "Q", "Hoàng Hậu", "Queen" }, { "K", "Vua", "King" },
}

-- Nghĩa riêng từng lá phụ: { xuôi, ngược, điểm (+1 thuận, 0 trung tính, -1 khó) }
local MINOR = {
    { -- Gậy
        { "Tia lửa sáng tạo, cảm hứng và năng lượng mới để bắt đầu một việc.", "Hứng khởi tắt giữa chừng, ý tưởng chưa thể khởi động.", 1 },
        { "Đứng giữa hai hướng đi, lên kế hoạch và nhìn xa.", "Sợ bước ra vùng quen thuộc, kế hoạch dở dang.", 0 },
        { "Tàu đã ra khơi, đang chờ kết quả từ nỗ lực mở rộng.", "Chậm trễ, kỳ vọng vượt thực tế, kế hoạch lệch hướng.", 1 },
        { "Ăn mừng, ổn định, về nhà; một cột mốc đáng vui.", "Bất hòa ở tổ ấm, ăn mừng bị hoãn, thiếu nền tảng.", 1 },
        { "Cạnh tranh, tranh cãi, va chạm ý kiến; ồn ào hơn là nguy hiểm.", "Né tránh xung đột, hoặc xung đột sắp được dàn xếp.", -1 },
        { "Chiến thắng, được công nhận, đám đông ủng hộ.", "Danh tiếng chao đảo, tự cao, hoặc thành công chưa được ghi nhận.", 1 },
        { "Giữ vững lập trường trước áp lực, bảo vệ điều mình có.", "Kiệt sức vì phòng thủ, muốn buông, bị lấn át.", -1 },
        { "Mọi thứ tăng tốc: tin nhắn, chuyến đi, tiến triển nhanh.", "Trễ nải, hiểu lầm thông tin, vội mà hỏng việc.", 1 },
        { "Mệt nhưng chưa gục, gần đích, cần thêm chút kiên cường.", "Cạn sức, cứng đầu phòng thủ, nghi ngờ mọi thứ.", -1 },
        { "Gánh quá nhiều trách nhiệm; gần tới đích nhưng nặng vai.", "Biết buông bớt gánh nặng, học cách ủy thác, hoặc bị đè bẹp.", -1 },
        { "Người trẻ nhiệt huyết, tin về dự án mới, tò mò khám phá.", "Ý tưởng lửa rơm, thiếu kiên nhẫn, tin chưa đáng tin.", 1 },
        { "Lao tới với đam mê, phiêu lưu, hành động nhanh.", "Nóng vội, bốc đồng, bỏ dở giữa chừng.", 0 },
        { "Tự tin, ấm áp, cuốn hút, quyết liệt mà có duyên.", "Ghen tị, nóng tính, kiểm soát vì bất an.", 1 },
        { "Nhà lãnh đạo có tầm nhìn, dám quyết, truyền cảm hứng.", "Độc đoán, nóng nảy, đòi hỏi quá cao ở người khác.", 0 },
    },
    { -- Cốc
        { "Tình cảm tràn đầy; khởi đầu một mối quan hệ hoặc niềm vui mới.", "Cảm xúc bị dồn nén, đóng lòng, tình cảm chưa được đáp lại.", 1 },
        { "Hai người đồng điệu; tình yêu hoặc hợp tác cân bằng.", "Lệch pha, hiểu lầm, quan hệ mất cân đối.", 1 },
        { "Bạn bè, tiệc tùng, niềm vui chung được sẻ chia.", "Ồn ào bề ngoài, ganh đua trong nhóm, quá đà.", 1 },
        { "Chán nản, thờ ơ trước cơ hội đang được đưa tới.", "Thoát khỏi trì trệ, bắt đầu để ý điều mới.", -1 },
        { "Tiếc nuối điều đã mất, quên mất những thứ còn lại.", "Chấp nhận mất mát, bắt đầu nhìn về phía trước.", -1 },
        { "Hoài niệm, ký ức tuổi thơ, món quà giản dị từ người cũ.", "Mắc kẹt trong quá khứ, tô hồng chuyện cũ.", 1 },
        { "Quá nhiều lựa chọn lung linh, mơ mộng, khó phân thật giả.", "Tỉnh mộng, chọn một hướng rõ ràng, nhìn thực tế hơn.", 0 },
        { "Rời bỏ điều không còn làm mình đầy đủ, đi tìm ý nghĩa sâu hơn.", "Muốn đi mà do dự, quay lại chỗ cũ, trốn tránh vấn đề.", 0 },
        { "Điều ước thành sự thật, hài lòng, tận hưởng thành quả.", "Thỏa mãn bề ngoài nhưng trống rỗng, tham hơn.", 1 },
        { "Hạnh phúc gia đình, viên mãn cảm xúc, bình yên lâu dài.", "Rạn nứt trong gia đình, hạnh phúc chỉ là hình thức.", 1 },
        { "Tin vui về tình cảm, thông điệp dịu dàng, trực giác nhạy.", "Quá nhạy cảm, ủy mị, tình cảm chưa chắc chắn.", 1 },
        { "Người lãng mạn tới với lời đề nghị, theo đuổi bằng cảm xúc.", "Hứa nhiều làm ít, thất thường, ảo tưởng.", 0 },
        { "Thấu cảm, dịu dàng, lắng nghe bằng trái tim.", "Dễ tổn thương, chìm trong cảm xúc, hy sinh quá mức.", 1 },
        { "Điềm tĩnh, khéo léo về cảm xúc, người cố vấn đáng tin.", "Kìm nén cảm xúc, thao túng nhẹ, nóng lạnh thất thường.", 0 },
    },
    { -- Kiếm
        { "Sự thật sáng tỏ, đầu óc minh mẫn, đột phá trong tư duy.", "Rối trí, lời nói gây tổn thương, quyết định thiếu cơ sở.", 1 },
        { "Bế tắc: nhắm mắt trước lựa chọn khó, giữ cân bằng gượng gạo.", "Buộc phải đối mặt, sự thật lộ ra, hết do dự.", 0 },
        { "Đau lòng, chia ly, lời nói làm tổn thương.", "Vết thương đang lành, buông nỗi đau; hoặc đau bị dồn nén.", -1 },
        { "Nghỉ ngơi, hồi sức; cần dừng lại để lành.", "Quay lại hoạt động quá sớm, kiệt sức kéo dài.", 0 },
        { "Thắng mà mất lòng người, xung đột không đáng, tự phụ.", "Hối hận, hòa giải, rút khỏi cuộc cãi vã.", -1 },
        { "Rời vùng sóng gió, chuyển tiếp chậm nhưng yên.", "Chưa thể đi, mang theo hành lý cũ, chuyển tiếp bị hoãn.", 1 },
        { "Lén lút, né tránh, mưu mẹo; hoặc làm một mình, không công khai.", "Bị phát hiện, thú nhận, quay lại làm cho đàng hoàng.", -1 },
        { "Tự trói mình bằng nỗi sợ; cảm giác bế tắc nhưng lối ra nằm ở chính bạn.", "Tự cởi trói, nhận ra mình có lựa chọn, bắt đầu hành động.", -1 },
        { "Lo âu, mất ngủ, nỗi sợ trong đầu lớn hơn thực tế.", "Nỗi lo giảm dần, tìm sự giúp đỡ; hoặc lo đến mức u ám.", -1 },
        { "Kết thúc đau đớn nhưng là đáy; sau đó chỉ còn đường lên.", "Hồi phục chậm, từ chối chấp nhận kết thúc.", -1 },
        { "Tò mò, đặt câu hỏi sắc, tin tức hoặc ý tưởng mới.", "Lời nói thiếu suy nghĩ, tin đồn, cãi cho thắng.", 0 },
        { "Lao vào bằng lý trí, nói thẳng, hành động dồn dập.", "Hấp tấp, hung hăng trong lời nói, thiếu chiến lược.", 0 },
        { "Sắc sảo, độc lập, nói thật, đã đi qua đau thương.", "Lạnh lùng, cay nghiệt, khép lòng để tự vệ.", 0 },
        { "Quyết định bằng lý trí, công bằng, quyền uy trí tuệ.", "Lạnh nhạt, dùng quyền lực hoặc lời lẽ đàn áp.", 0 },
    },
    { -- Tiền
        { "Cơ hội vật chất cụ thể: việc mới, khoản thu, nền móng vững.", "Cơ hội trượt tay, đầu tư thiếu tính toán.", 1 },
        { "Xoay xở nhiều việc, linh hoạt giữa tiền bạc và thời gian.", "Quá tải, chi tiêu mất cân đối, rối thứ tự ưu tiên.", 0 },
        { "Làm việc nhóm, tay nghề được công nhận, cùng nhau xây dựng.", "Thiếu phối hợp, làm cho có, không ai nghe ai.", 1 },
        { "Giữ chặt tiền của, an toàn, kiểm soát; dễ thành keo kiệt.", "Buông tay chi tiêu, hoặc sợ mất mà bám víu quá mức.", 0 },
        { "Thiếu thốn, khó khăn tiền bạc hoặc cảm giác bị bỏ rơi; sự giúp đỡ ở ngay cửa.", "Khó khăn bắt đầu qua, chịu nhận giúp đỡ, hồi phục dần.", -1 },
        { "Cho và nhận cân bằng, giúp đỡ, chia sẻ nguồn lực công bằng.", "Cho vay có điều kiện, bất bình đẳng, nợ ân tình.", 1 },
        { "Chờ thu hoạch, đánh giá lại công sức, kiên nhẫn.", "Thiếu kiên nhẫn, công sức chưa được đáp lại, nên đổi hướng.", 0 },
        { "Chăm chỉ rèn nghề, tập trung tay nghề, tiến bộ đều đặn.", "Làm đi làm lại vô vị, cầu toàn, mất động lực.", 1 },
        { "Tự lập, dư dả nhờ chính mình, tận hưởng thành quả.", "Sung túc bề ngoài, cô đơn trong giàu có, phụ thuộc.", 1 },
        { "Gia nghiệp bền vững, tài sản lâu dài, an toàn nhiều thế hệ.", "Bất ổn tài chính gia đình, tranh chấp thừa kế.", 1 },
        { "Học nghề, cơ hội học bổng hoặc việc nhỏ, tinh thần thực tế.", "Lười biếng, mục tiêu mơ hồ, chưa bắt tay làm.", 1 },
        { "Chậm mà chắc, đáng tin, kiên trì từng bước.", "Trì trệ, cứng nhắc, nhàm chán.", 0 },
        { "Thực tế, chu đáo, biết quản lý tiền bạc và tổ ấm.", "Lo vật chất quá mức, bỏ bê bản thân.", 1 },
        { "Thành đạt, vững vàng, giàu có và hào phóng.", "Tham, bảo thủ, coi tiền là thước đo mọi thứ.", 1 },
    },
}

local MPOL = { 1, 1, 0, 1, 1, 0, 1, 1, 1, 0, 1, 0, 0, 0, 1, -1, -1, 1, -1, 1, 1, 1 }
local MADV = {
    "Hãy bước đi, nhưng nhìn xuống chân một chút.",
    "Dùng đủ công cụ đang có và bắt tay làm ngay.",
    "Đừng vội quyết; lắng nghe linh cảm trước.",
    "Chăm sóc và để mọi thứ lớn lên tự nhiên.",
    "Lập kế hoạch rõ ràng và giữ kỷ luật.",
    "Hỏi người có kinh nghiệm; học quy tắc trước khi phá.",
    "Chọn theo giá trị thật của mình, không theo áp lực.",
    "Giữ hướng đi, điều khiển cả hai con ngựa của chính mình.",
    "Mềm mỏng và kiên nhẫn thắng sự cứng rắn.",
    "Dành thời gian một mình để tìm câu trả lời.",
    "Chu kỳ đang xoay; đừng bám vào hiện trạng.",
    "Nhìn thẳng sự thật và chịu trách nhiệm.",
    "Dừng lại, đổi góc nhìn trước khi hành động.",
    "Cho phép điều cũ kết thúc để điều mới đến.",
    "Pha trộn vừa phải, đừng cực đoan.",
    "Gọi tên điều đang trói bạn; chìa khóa nằm trong tay bạn.",
    "Giữ bình tĩnh; xây lại trên nền thật hơn.",
    "Giữ hy vọng và tiếp tục chăm sóc bản thân.",
    "Đừng quyết khi chưa đủ thông tin; chờ trời sáng.",
    "Tận hưởng và chia sẻ niềm vui.",
    "Nhìn lại, tha thứ và đáp lại tiếng gọi bên trong.",
    "Khép lại trọn vẹn rồi mở chương mới.",
}

local CARDS = {}
for i, m in ipairs(MAJOR) do
    CARDS[#CARDS + 1] = {
        idx = #CARDS + 1, kind = "major", name = m[1], en = m[2], up = m[3], rev = m[4],
        top = ROMAN[i - 1], bottom = "ẨN CHÍNH", pol = MPOL[i], adv = MADV[i],
    }
end
for si, su in ipairs(SUITS) do
    for ri, r in ipairs(RANKS) do
        local mn = MINOR[si][ri]
        CARDS[#CARDS + 1] = {
            idx = #CARDS + 1, kind = su[3], suit = si, name = r[2] .. " " .. su[1], en = r[3] .. " of " .. su[2],
            up = mn[1], rev = mn[2], pol = mn[3], domain = su[4], top = r[1], bottom = su[5],
        }
    end
end

-- ===== ảnh bộ Rider-Waite-Smith (Wikimedia Commons, công khai) =====
local IMG = {
    "9/90/RWS_Tarot_00_Fool.jpg",
    "d/de/RWS_Tarot_01_Magician.jpg",
    "8/88/RWS_Tarot_02_High_Priestess.jpg",
    "d/d2/RWS_Tarot_03_Empress.jpg",
    "c/c3/RWS_Tarot_04_Emperor.jpg",
    "8/8d/RWS_Tarot_05_Hierophant.jpg",
    "d/db/RWS_Tarot_06_Lovers.jpg",
    "9/9b/RWS_Tarot_07_Chariot.jpg",
    "f/f5/RWS_Tarot_08_Strength.jpg",
    "4/4d/RWS_Tarot_09_Hermit.jpg",
    "3/3c/RWS_Tarot_10_Wheel_of_Fortune.jpg",
    "e/e0/RWS_Tarot_11_Justice.jpg",
    "2/2b/RWS_Tarot_12_Hanged_Man.jpg",
    "d/d7/RWS_Tarot_13_Death.jpg",
    "f/f8/RWS_Tarot_14_Temperance.jpg",
    "5/55/RWS_Tarot_15_Devil.jpg",
    "5/53/RWS_Tarot_16_Tower.jpg",
    "d/db/RWS_Tarot_17_Star.jpg",
    "7/7f/RWS_Tarot_18_Moon.jpg",
    "1/17/RWS_Tarot_19_Sun.jpg",
    "d/dd/RWS_Tarot_20_Judgement.jpg",
    "f/ff/RWS_Tarot_21_World.jpg",
    "1/11/Wands01.jpg",
    "0/0f/Wands02.jpg",
    "f/ff/Wands03.jpg",
    "a/a4/Wands04.jpg",
    "9/9d/Wands05.jpg",
    "3/3b/Wands06.jpg",
    "e/e4/Wands07.jpg",
    "6/6b/Wands08.jpg",
    "e/e7/Wands09.jpg",
    "0/0b/Wands10.jpg",
    "6/6a/Wands11.jpg",
    "1/16/Wands12.jpg",
    "0/0d/Wands13.jpg",
    "c/ce/Wands14.jpg",
    "3/36/Cups01.jpg",
    "f/f8/Cups02.jpg",
    "7/7a/Cups03.jpg",
    "3/35/Cups04.jpg",
    "d/d7/Cups05.jpg",
    "1/17/Cups06.jpg",
    "a/ae/Cups07.jpg",
    "6/60/Cups08.jpg",
    "2/24/Cups09.jpg",
    "8/84/Cups10.jpg",
    "a/ad/Cups11.jpg",
    "f/fa/Cups12.jpg",
    "6/62/Cups13.jpg",
    "0/04/Cups14.jpg",
    "1/1a/Swords01.jpg",
    "9/9e/Swords02.jpg",
    "0/02/Swords03.jpg",
    "b/bf/Swords04.jpg",
    "2/23/Swords05.jpg",
    "2/29/Swords06.jpg",
    "3/34/Swords07.jpg",
    "a/a7/Swords08.jpg",
    "2/2f/Swords09.jpg",
    "d/d4/Swords10.jpg",
    "4/4c/Swords11.jpg",
    "b/b0/Swords12.jpg",
    "d/d4/Swords13.jpg",
    "3/33/Swords14.jpg",
    "f/fd/Pents01.jpg",
    "9/9f/Pents02.jpg",
    "4/42/Pents03.jpg",
    "3/35/Pents04.jpg",
    "9/96/Pents05.jpg",
    "a/a6/Pents06.jpg",
    "6/6a/Pents07.jpg",
    "4/49/Pents08.jpg",
    "f/f0/Pents09.jpg",
    "4/42/Pents10.jpg",
    "e/ec/Pents11.jpg",
    "d/d5/Pents12.jpg",
    "8/88/Pents13.jpg",
    "1/1c/Pents14.jpg",
}
local IMGBASE = "https://upload.wikimedia.org/wikipedia/commons/"
local IMGDIR = "/mnt/us/vn_dash/tarot_img"

local function img_file(i) return IMGDIR .. "/" .. i .. ".jpg" end

local function have_img(i)
    local f = io.open(img_file(i), "rb")
    if not f then return false end
    local sz = f:seek("end")
    f:close()
    return sz and sz > 4000
end

local function img_url(i)
    local d, f = IMG[i]:match("^(%w/%w%w)/(.+)$")
    return IMGBASE .. "thumb/" .. d .. "/" .. f .. "/500px-" .. f
end

-- tải song song các ảnh còn thiếu; trả về true nếu tải được ít nhất 1 ảnh
local function fetch_imgs(list)
    local cmds = {}
    for _, i in ipairs(list) do
        if not have_img(i) then
            cmds[#cmds + 1] = string.format('curl -sS -m 30 --connect-timeout 8 -L -A "Mozilla/5.0" -o "%s.part" "%s" 2>/dev/null &', img_file(i), img_url(i))
        end
    end
    if #cmds == 0 then return true end
    os.execute('mkdir -p "' .. IMGDIR .. '"')
    os.execute(table.concat(cmds, " ") .. " wait")
    local got = false
    for _, i in ipairs(list) do
        local tmp = img_file(i) .. ".part"
        local f = io.open(tmp, "rb")
        if f then
            local head = f:read(3)
            local sz = f:seek("end")
            f:close()
            if head == "\255\216\255" and sz and sz > 4000 then
                os.rename(tmp, img_file(i))
                got = true
            else
                os.remove(tmp)
            end
        end
    end
    return got
end

local img_cache = {}
local function clear_imgs()
    for k, b in pairs(img_cache) do
        if b then pcall(function() b:free() end) end
        img_cache[k] = nil
    end
end

-- ===== phân tích câu hỏi =====
local FOLD = {}
do
    local lower = {
        a = "àáảãạăằắẳẵặâầấẩẫậ", e = "èéẻẽẹêềếểễệ", i = "ìíỉĩị", o = "òóỏõọôồốổỗộơờớởỡợ",
        u = "ùúủũụưừứửữự", y = "ỳýỷỹỵ", d = "đ",
    }
    local upper = {
        a = "ÀÁẢÃẠĂẰẮẲẴẶÂẦẤẨẪẬ", e = "ÈÉẺẼẸÊỀẾỂỄỆ", i = "ÌÍỈĨỊ", o = "ÒÓỎÕỌÔỒỐỔỖỘƠỜỚỞỠỢ",
        u = "ÙÚỦŨỤƯỪỨỬỮỰ", y = "ỲÝỶỸỴ", d = "Đ",
    }
    for _, tbl in ipairs({ lower, upper }) do
        for base, set in pairs(tbl) do
            for ch in set:gmatch("[\1-\127\194-\244][\128-\191]*") do FOLD[ch] = base end
        end
    end
end

local function fold(s)
    local out = {}
    for ch in tostring(s):gmatch("[\1-\127\194-\244][\128-\191]*") do
        out[#out + 1] = FOLD[ch] or ch:lower()
    end
    local r = table.concat(out)
    r = r:gsub("[^%w]", " ")
    return " " .. r:gsub("%s+", " ") .. " "
end

local TOPICS = {
    love = { name = "chuyện tình cảm", suits = { [2] = true },
        kw = { "yeu", "tinh yeu", "nguoi yeu", "crush", "hen ho", "chia tay", "cuoi", "hon nhan", "tai hop", "ban trai", "ban gai", "nguoi ay", "anh ay", "co ay", "tinh cam", "vo", "chong", "nguoi cu" } },
    work = { name = "công việc", suits = { [1] = true, [4] = true },
        kw = { "cong viec", "viec lam", "su nghiep", "xin viec", "nhay viec", "thang chuc", "cong ty", "sep", "dong nghiep", "du an", "khoi nghiep", "kinh doanh", "phong van", "nghe nghiep" } },
    money = { name = "tiền bạc", suits = { [4] = true },
        kw = { "tien", "tai chinh", "dau tu", "luong", "no nan", "thu nhap", "chung khoan", "vang", "mua nha", "nha dat", "co phieu", "tiet kiem" } },
    health = { name = "sức khỏe", suits = { [4] = true, [1] = true },
        kw = { "suc khoe", "benh", "dau om", "om dau", "giam can", "tap luyen", "kham", "phau thuat", "mat ngu", "stress", "tinh than" } },
    study = { name = "việc học", suits = { [3] = true, [4] = true },
        kw = { "hoc", "thi", "ky thi", "diem", "truong", "du hoc", "dai hoc", "tot nghiep", "luan van", "bang cap" } },
}
local TOPIC_ORDER = { "love", "work", "money", "health", "study" }

local function detect_topic(q)
    local fs = fold(q)
    local best, bn = nil, 0
    for _, key in ipairs(TOPIC_ORDER) do
        local n = 0
        for _, kw in ipairs(TOPICS[key].kw) do
            if fs:find(" " .. kw .. " ", 1, true) then n = n + 1 end
        end
        if n > bn then best, bn = key, n end
    end
    return best
end

local function is_yesno(q)
    local fs = fold(q)
    for _, kw in ipairs({ "nen", "khong", "co duoc", "co phai", "lieu", "co nen", "co the", "duoc khong" }) do
        if fs:find(" " .. kw .. " ", 1, true) then return true end
    end
    return false
end

local function is_timing(q)
    local fs = fold(q)
    return fs:find(" khi nao ", 1, true) or fs:find(" bao gio ", 1, true) or fs:find(" bao lau ", 1, true)
end

local function score_of(d)
    local p = d.card.pol or 0
    if d.rev then
        if p > 0 then return -1 elseif p < 0 then return 0.5 else return 0 end
    end
    return p
end

local function lens_of(c, topic)
    if not topic then return "" end
    local t = TOPICS[topic]
    if c.kind == "major" then
        return " Đây là lá Ẩn Chính nên nó chi phối cả bức tranh " .. t.name .. " của bạn."
    end
    if t.suits[c.suit] then
        return " Lá thuộc bộ " .. SUITS[c.suit][1] .. " – đúng lĩnh vực " .. t.name .. ", nên đây là thông điệp trực tiếp cho câu hỏi."
    end
    return " Bộ " .. SUITS[c.suit][1] .. " nói về " .. SUITS[c.suit][4] .. ": hãy nhìn " .. t.name .. " của bạn qua lăng kính đó."
end

local function compose_reading(draws, question, deal_rev)
    local q = tostring(question or ""):gsub("^%s+", ""):gsub("%s+$", "")
    local topic = (q ~= "") and detect_topic(q) or nil
    local paras = {}
    local labels = #draws == 3 and { "QUÁ KHỨ", "HIỆN TẠI", "TƯƠNG LAI" } or { "LÁ BÀI" }
    local total = 0
    for i, d in ipairs(draws) do
        local c = d.card
        local s = labels[i] .. " – " .. c.name .. (d.rev and " (ngược)" or "") .. ": " ..
            (d.rev and c.rev or c.up) .. lens_of(c, topic)
        paras[#paras + 1] = s
        total = total + score_of(d)
    end
    local n = #draws
    if n == 3 then
        local diff = score_of(draws[3]) - score_of(draws[1])
        local t
        if diff > 0.5 then t = "Mạch chuyện đang đi lên: từ nặng nề dần sang thuận lợi."
        elseif diff < -0.5 then t = "Mạch chuyện đang đi xuống: cần thận trọng ở chặng sắp tới."
        else t = "Mạch chuyện khá ổn định, không đổi chiều đột ngột." end
        paras[#paras + 1] = "TỔNG QUAN – " .. t
    end
    if q ~= "" and is_yesno(q) then
        local thr = (n == 1) and 1 or 1.5
        local t
        if total >= thr then t = "bài nghiêng về CÓ / THUẬN LỢI."
        elseif total <= -thr then t = "bài nghiêng về KHÔNG / NÊN CÂN NHẮC LẠI."
        else t = "bài chưa nghiêng hẳn bên nào – kết quả tùy vào lựa chọn của bạn." end
        paras[#paras + 1] = "VỀ CÂU HỎI CÓ/KHÔNG – " .. t
    end
    if q ~= "" and is_timing(q) then
        paras[#paras + 1] = "Tarot không đoán được ngày giờ; hãy xem lá cuối như xu hướng chung."
    end
    local last = draws[n]
    local adv = last.card.adv
    if not adv then
        local p = last.card.pol or 0
        adv = p > 0 and "Thuận đà thì hành động, nhưng đừng chủ quan."
            or p < 0 and "Chậm lại, chăm sóc bản thân và rút bài học trước khi tiến."
            or "Cân nhắc kỹ; kết quả còn tùy lựa chọn của bạn."
    end
    if last.rev then adv = adv .. " Vì lá ngược, năng lượng này đang bị chặn hoặc cần nhìn vào bên trong trước." end
    paras[#paras + 1] = "LỜI KHUYÊN – " .. adv
    if topic == "health" or topic == "money" then
        paras[#paras + 1] = "Tarot chỉ để suy ngẫm, không thay cho tư vấn y tế hay tài chính."
    end
    return paras, q, topic
end

-- ===== hình vẽ đơn giản cho từng bộ (đơn vị: s, gốc ở tâm) =====
local SHAPES = {}
do
    local s = {}
    s[#s + 1] = { "r", -0.05, -0.9, 0.1, 1.8 }
    s[#s + 1] = { "r", 0.05, -0.55, 0.28, 0.07 }
    s[#s + 1] = { "r", -0.33, -0.25, 0.28, 0.07 }
    s[#s + 1] = { "r", 0.05, 0.05, 0.28, 0.07 }
    s[#s + 1] = { "r", -0.33, 0.35, 0.28, 0.07 }
    SHAPES.wands = s
    local c = {}
    for i = 0, 6 do
        local w = 1.1 - i * 0.1
        c[#c + 1] = { "r", -w / 2, -0.8 + i * 0.1, w, 0.1 }
    end
    c[#c + 1] = { "r", -0.05, -0.1, 0.1, 0.7 }
    c[#c + 1] = { "r", -0.33, 0.6, 0.66, 0.1 }
    SHAPES.cups = c
    local w = {}
    w[#w + 1] = { "r", -0.08, -0.75, 0.16, 1.4 }
    for i = 0, 4 do
        local ww = 0.16 * (1 - i / 5)
        w[#w + 1] = { "r", -ww / 2, -0.75 - (i + 1) * 0.06, ww, 0.06 }
    end
    w[#w + 1] = { "r", -0.42, 0.6, 0.84, 0.1 }
    w[#w + 1] = { "r", -0.05, 0.7, 0.1, 0.32 }
    w[#w + 1] = { "c", 0, 1.06, 0.09, BLACK }
    SHAPES.swords = w
    local p = {}
    p[#p + 1] = { "c", 0, 0, 0.8, BLACK }
    p[#p + 1] = { "c", 0, 0, 0.72, WHITE }
    p[#p + 1] = { "c", 0, 0, 0.58, BLACK }
    p[#p + 1] = { "c", 0, 0, 0.5, WHITE }
    p[#p + 1] = { "r", -0.48, -0.03, 0.96, 0.06 }
    p[#p + 1] = { "r", -0.03, -0.48, 0.06, 0.96 }
    SHAPES.pentacles = p
    local m = {}
    m[#m + 1] = { "c", 0, 0, 0.5, BLACK }
    m[#m + 1] = { "c", 0, 0, 0.4, WHITE }
    m[#m + 1] = { "c", 0, 0, 0.18, BLACK }
    m[#m + 1] = { "r", -0.04, -0.95, 0.08, 0.3 }
    m[#m + 1] = { "r", -0.04, 0.65, 0.08, 0.3 }
    m[#m + 1] = { "r", -0.95, -0.04, 0.3, 0.08 }
    m[#m + 1] = { "r", 0.65, -0.04, 0.3, 0.08 }
    SHAPES.major = m
end

local function paint_shapes(bb, cx, cy, s, shapes, flip)
    for _, sh in ipairs(shapes) do
        if sh[1] == "r" then
            local x, y, w, h = sh[2], sh[3], sh[4], sh[5]
            if flip then
                x, y = -(x + w), -(y + h)
            end
            bb:paintRect(math.floor(cx + x * s), math.floor(cy + y * s), math.max(1, math.floor(w * s)), math.max(1, math.floor(h * s)), BLACK)
        else
            local x, y, r = sh[2], sh[3], sh[4]
            if flip then x, y = -x, -y end
            local rr = math.max(1, math.floor(r * s))
            bb:paintRoundedRect(math.floor(cx + x * s) - rr, math.floor(cy + y * s) - rr, 2 * rr, 2 * rr, sh[5], rr)
        end
    end
end

local function card_art(bb, x, y, w, h, c, rev)
    local rad = math.floor(w * 0.07)
    bb:paintRoundedRect(x, y, w, h, BLACK, rad)
    bb:paintRoundedRect(x + 5, y + 5, w - 10, h - 10, WHITE, math.max(2, rad - 3))
    bb:paintBorder(x + 16, y + 16, w - 32, h - 32, 2, BLACK, 0)
    local fs = math.max(16, math.floor(w * 0.13))
    txt(bb, c.top, x + math.floor(w / 2), y + 24, fs, { center = true, bold = true })
    local cx, cy = x + math.floor(w / 2), y + math.floor(h * 0.5)
    paint_shapes(bb, cx, cy, math.floor(w * 0.3), SHAPES[c.kind] or SHAPES.major, rev)
    txt(bb, c.bottom, x + math.floor(w / 2), y + h - 24 - math.floor(fs * 0.9), math.max(14, math.floor(w * 0.085)), { center = true, bold = true })
end

-- ===== bốc bài =====
local function seed()
    local n = 0
    local f = io.open("/dev/urandom", "rb")
    if f then
        local b = f:read(4)
        f:close()
        if b then
            for i = 1, #b do n = n * 256 + b:byte(i) end
        end
    end
    math.randomseed((n + os.time()) % 2147483647)
    for _ = 1, 6 do math.random() end
end

local function deal(n, allow_rev)
    local deck = {}
    for i = 1, #CARDS do deck[i] = i end
    local out = {}
    for k = 1, n do
        local j = k + math.random(0, #deck - k)
        deck[k], deck[j] = deck[j], deck[k]
        out[#out + 1] = { card = CARDS[deck[k]], rev = allow_rev and (math.random() < 0.5) or false }
    end
    return out
end

local function draw_card(bb, x, y, w, h, c, rev)
    local key = c.idx .. "_" .. w .. "_" .. h .. (rev and "r" or "")
    local b = img_cache[key]
    if b == nil then
        b = false
        if have_img(c.idx) then
            local ok, res = pcall(function()
                local RenderImage = require("ui/renderimage")
                local src = RenderImage:renderImageFile(img_file(c.idx), false, w, h)
                if src and rev then
                    local r = src:rotatedCopy(180)
                    src:free()
                    src = r
                end
                return src
            end)
            if ok and res then b = res end
        end
        img_cache[key] = b
    end
    if b then
        bb:blitFrom(b, x, y, 0, 0, b:getWidth(), b:getHeight())
        bb:paintBorder(x, y, w, h, 2, BLACK, 0)
        return true
    end
    card_art(bb, x, y, w, h, c, rev)
    return false
end

local function fit_text(bb, text, x, y, w, hmax, sizes)
    for k, px in ipairs(sizes) do
        local tb = TextBoxWidget:new{ text = text, face = face(px), width = w, fgcolor = BLACK }
        local h = tb:getSize().h
        if h <= hmax or k == #sizes then
            tb:paintTo(bb, x, y)
            tb:free()
            return h
        end
        tb:free()
    end
    return 0
end

local function save_history(draws, question)
    pcall(function()
        local f = io.open(HISTORY, "a")
        if f then
            local parts = {}
            for _, d in ipairs(draws) do
                parts[#parts + 1] = d.card.name .. " (" .. d.card.en .. ")" .. (d.rev and " [ngược]" or "")
            end
            local q = (question and question ~= "") and (" ? " .. question) or ""
            f:write(os.date("%Y-%m-%d %H:%M ") .. table.concat(parts, " | ") .. q .. "\n")
            f:close()
        end
    end)
end

-- ===== màn hình =====
local Tarot = InputContainer:extend{
    name = "vn_tarot",
    covers_fullscreen = true,
    allow_rev = true,
    deal_rev = false,
    view = "cards",
    question = "",
}

function Tarot:meaning_of(d)
    if d.rev then return d.card.rev end
    return d.card.up
end

function Tarot:draw_orient(bb, x, y, rev, px)
    local label = rev and "NGƯỢC" or "XUÔI"
    local w = math.floor(px * 4.6)
    local h = math.floor(px * 1.7)
    if rev then
        bb:paintBorder(x, y, w, h, 3, BLACK, math.floor(h / 2))
        txt(bb, label, x + math.floor(w / 2), y + math.floor(px * 0.3), px, { center = true, bold = true })
    else
        bb:paintRoundedRect(x, y, w, h, BLACK, math.floor(h / 2))
        txt(bb, label, x + math.floor(w / 2), y + math.floor(px * 0.3), px, { center = true, bold = true, color = WHITE })
    end
    return w, h
end

function Tarot:draw_one(bb, x0, top, bottom, W, mx)
    local d = self.draws[1]
    local c = d.card
    local ah = bottom - top - 10
    local aw = math.floor(ah * 0.578)
    if aw > math.floor(W * 0.34) then
        aw = math.floor(W * 0.34)
        ah = math.floor(aw / 0.578)
    end
    draw_card(bb, mx, top + 5, aw, ah, c, d.rev)
    local px = mx + aw + 50
    local pw = W - mx - px
    txt(bb, c.name, px, top + 10, 64, { bold = true, max_width = pw })
    txt(bb, c.en, px, top + 88, 32, { color = GRAY5, max_width = pw })
    local y = top + 140
    if self.deal_rev then
        local _, oh = self:draw_orient(bb, px, y, d.rev, 30)
        y = y + oh + 34
    else
        y = y + 6
    end
    local tb = TextBoxWidget:new{ text = self:meaning_of(d), face = face(40), width = pw, fgcolor = BLACK }
    tb:paintTo(bb, px, y)
    y = y + tb:getSize().h + 30
    tb:free()
    if c.domain and y < bottom - 60 then
        local t2 = TextBoxWidget:new{ text = "Trong lĩnh vực: " .. c.domain .. ".", face = face(30), width = pw, fgcolor = GRAY5 }
        t2:paintTo(bb, px, y)
        t2:free()
    elseif c.kind == "major" and y < bottom - 60 then
        txt(bb, "Lá Ẩn Chính: thông điệp lớn của giai đoạn này", px, y, 28, { color = GRAY5, max_width = pw })
    end
end

function Tarot:draw_three(bb, top, bottom, W, mx)
    local gap = 24
    local cw = math.floor((W - 2 * mx - 2 * gap) / 3)
    local labels = { "QUÁ KHỨ", "HIỆN TẠI", "TƯƠNG LAI" }
    local ah = math.floor((bottom - top) * 0.5)
    local aw = math.floor(ah * 0.578)
    if aw > cw - 40 then
        aw = cw - 40
        ah = math.floor(aw / 0.578)
    end
    for i, d in ipairs(self.draws) do
        local x = mx + (i - 1) * (cw + gap)
        bb:paintBorder(x, top, cw, bottom - top, 3, BLACK, 24)
        txt(bb, labels[i] or "", x + math.floor(cw / 2), top + 12, 26, { center = true, bold = true, color = GRAY5 })
        local ax = x + math.floor((cw - aw) / 2)
        draw_card(bb, ax, top + 52, aw, ah, d.card, d.rev)
        local y = top + 52 + ah + 12
        txt(bb, d.card.name, x + math.floor(cw / 2), y, 32, { center = true, bold = true, max_width = cw - 24 })
        y = y + 42
        if self.deal_rev then
            local ow = math.floor(22 * 4.6)
            self:draw_orient(bb, x + math.floor((cw - ow) / 2), y, d.rev, 22)
            y = y + math.floor(22 * 1.7) + 10
        end
        local tb = TextBoxWidget:new{ text = self:meaning_of(d), face = face(24), width = cw - 40, fgcolor = BLACK }
        if y + tb:getSize().h <= bottom - 8 then tb:paintTo(bb, x + 20, y) end
        tb:free()
    end
end

function Tarot:draw_reading(bb, top, bottom, W, mx)
    local paras, q, topic = compose_reading(self.draws, self.question, self.deal_rev)
    local y = top
    local head
    if q ~= "" then head = "Câu hỏi: " .. q else head = "Chưa đặt câu hỏi – luận giải tổng quát (bấm CÂU HỎI để hỏi)." end
    local hb = TextBoxWidget:new{ text = head, face = face(34), width = W - 2 * mx, fgcolor = BLACK, bold = true }
    hb:paintTo(bb, mx, y)
    y = y + hb:getSize().h + 10
    hb:free()
    bb:paintRect(mx, y, W - 2 * mx, 3, BLACK)
    y = y + 16
    fit_text(bb, table.concat(paras, "\n\n"), mx, y, W - 2 * mx, bottom - y, { 34, 31, 28, 26, 24, 22 })
end

function Tarot:ask()
    local InputDialog = require("ui/widget/inputdialog")
    local dlg
    local function done(save)
        local txtq
        if save then txtq = dlg:getInputText() end
        UIManager:close(dlg)
        if save then
            txtq = tostring(txtq or ""):gsub("[\r\n]+", " "):gsub("^%s+", ""):gsub("%s+$", "")
            if #txtq > 240 then txtq = txtq:sub(1, 240) end
            self.question = txtq
            if self.draws and txtq ~= "" then self.view = "read" end
        end
        UIManager:setDirty(self, "full")
    end
    dlg = InputDialog:new{
        title = "Câu hỏi của bạn",
        input = self.question or "",
        input_hint = "Ví dụ: Công việc sắp tới có thuận lợi không?",
        buttons = {
            {
                { text = "Hủy", callback = function() done(false) end },
                { text = "Xóa", callback = function() self.question = ""; done(false) end },
                { text = "Lưu", is_enter_default = true, callback = function() done(true) end },
            },
        },
    }
    UIManager:show(dlg)
    pcall(function() dlg:onShowKeyboard() end)
end

function Tarot:paintTo(bb, x, y)
    local W, H = self.dimen.w, self.dimen.h
    self.hits = {}
    bb:paintRect(x, y, W, H, WHITE)
    local ok, err = pcall(function()
        local mx = 36
        bb:paintRoundedRect(mx, 30, W - 2 * mx, 84, BLACK, 24)
        txt(bb, "BỐC TAROT", mx + 34, 42, 44, { bold = true, color = WHITE })
        txt(bb, os.date("%H:%M  %d/%m/%Y"), W - mx - 34, 56, 26, { right = true, color = WHITE })
        local top, bottom = 140, H - 30 - 84 - 22 - 20
        if self.question and self.question ~= "" and self.view ~= "read" then
            txt(bb, "Hỏi: " .. self.question, mx, top - 2, 30, { color = GRAY5, max_width = W - 2 * mx })
            top = top + 44
        end
        if self.shuffling then
            txt(bb, "Đang xáo bài…", math.floor(W / 2), math.floor((top + bottom) / 2) - 40, 56, { center = true, bold = true })
            txt(bb, "Hãy giữ câu hỏi trong đầu", math.floor(W / 2), math.floor((top + bottom) / 2) + 40, 30, { center = true, color = GRAY5 })
        elseif not self.draws then
            txt(bb, "Nghĩ về một câu hỏi, rồi bấm BỐC", math.floor(W / 2), math.floor((top + bottom) / 2) - 50, 52, { center = true, bold = true })
            txt(bb, "Bấm CÂU HỎI để nhập câu hỏi và nhận luận giải theo câu hỏi", math.floor(W / 2), math.floor((top + bottom) / 2) + 40, 30, { center = true, color = GRAY5 })
        elseif self.view == "read" then
            self:draw_reading(bb, top, bottom, W, mx)
        elseif #self.draws == 1 then
            self:draw_one(bb, x, top, bottom, W, mx)
        else
            self:draw_three(bb, top, bottom, W, mx)
        end
        if self.draws and not self.shuffling and self.img_missing and self.view ~= "read" then
            txt(bb, "Chưa tải được ảnh bài – bật Wi-Fi rồi bốc lại để có ảnh", W - mx, bottom + 2, 22, { right = true, color = GRAY5 })
        end
        -- nút
        local list = {
            { "BỐC 1 LÁ", function() self:deal_n(1) end, true, 1.2 },
            { "BỐC 3 LÁ", function() self:deal_n(3) end, true, 1.2 },
            { "CÂU HỎI", function() self:ask() end, false, 1.2 },
            { self.view == "read" and "XEM BÀI" or "LUẬN GIẢI", function()
                if not self.draws or self.shuffling then return end
                self.view = (self.view == "read") and "cards" or "read"
                UIManager:setDirty(self, "ui")
            end, false, 1.3 },
            { self.allow_rev and "NGƯỢC: BẬT" or "NGƯỢC: TẮT", function()
                self.allow_rev = not self.allow_rev
                UIManager:setDirty(self, "ui")
            end, false, 1.5 },
            { "THOÁT", function() self:close() end, false, 1 },
        }
        local bh, gap = 84, 16
        local by = H - 30 - bh - 22
        local totw = 0
        for _, b in ipairs(list) do totw = totw + b[4] end
        local avail = W - 2 * mx - (#list - 1) * gap
        local bx = mx
        for _, b in ipairs(list) do
            local bw = math.floor(avail * b[4] / totw)
            if b[3] then
                bb:paintRoundedRect(bx, by, bw, bh, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 22, 28, { center = true, bold = true, color = WHITE })
            else
                bb:paintBorder(bx, by, bw, bh, 4, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 22, 28, { center = true, bold = true })
            end
            self.hits[#self.hits + 1] = { x = bx, y = by, w = bw, h = bh, fn = b[2] }
            bx = bx + bw + gap
        end
    end)
    if not ok then
        txt(bb, "Lỗi hiển thị: " .. tostring(err), 40, 260, 24, { max_width = W - 80 })
    end
end

function Tarot:deal_n(n)
    if self.shuffling then return end
    self.shuffling = true
    self.view = "cards"
    UIManager:setDirty(self, "full")
    UIManager:scheduleIn(0.6, function()
        local ok, err = pcall(function()
            seed()
            clear_imgs()
            self.deal_rev = self.allow_rev
            self.draws = deal(n, self.allow_rev)
            local list = {}
            for _, d in ipairs(self.draws) do list[#list + 1] = d.card.idx end
            fetch_imgs(list)
            self.img_missing = false
            for _, i in ipairs(list) do
                if not have_img(i) then self.img_missing = true end
            end
            save_history(self.draws, self.question)
        end)
        self.shuffling = false
        if not ok then self.draws = self.draws or nil end
        UIManager:setDirty(self, "full")
    end)
end

function Tarot:onCloseTarot()
    self:close()
    return true
end

function Tarot:onTap(_, ges)
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

function Tarot:close()
    clear_imgs()
    if self.old_rotation ~= nil and self.old_rotation ~= Screen:getRotationMode() then
        Screen:setRotationMode(self.old_rotation)
    end
    UIManager:close(self)
    UIManager:setDirty("all", "full")
    if self.on_close then pcall(self.on_close) end
end

function Tarot:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
    self.key_events = {
        CloseTarot = { { "Back" } },
    }
    self.hits = {}
end

function Tarot:start()
    self.old_rotation = Screen:getRotationMode()
    if self.old_rotation ~= 1 then Screen:setRotationMode(1) end
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = { Tap = { GestureRange:new{ ges = "tap", range = self.dimen } } }
    self.key_events = { CloseTarot = { { "Back" } } }
    UIManager:show(self, "full")
end

local M = {}
function M.open(on_close)
    local w = Tarot:new{ on_close = on_close }
    w:start()
    return w
end
return M

