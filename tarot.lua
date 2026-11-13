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
    { "A", "Át", "Ace", "Khởi đầu mới, cơ hội, tiềm năng.", "Cơ hội bị bỏ lỡ, khởi đầu trục trặc." },
    { "2", "Hai", "Two", "Cân bằng, lựa chọn, hợp tác.", "Mất cân bằng, do dự." },
    { "3", "Ba", "Three", "Phát triển, hợp tác, kết quả đầu tiên.", "Chậm tiến độ, thiếu phối hợp." },
    { "4", "Bốn", "Four", "Ổn định, nghỉ ngơi, củng cố.", "Trì trệ, bất an." },
    { "5", "Năm", "Five", "Thử thách, xung đột, mất mát.", "Hồi phục sau xung đột, buông bỏ." },
    { "6", "Sáu", "Six", "Hòa hợp, chuyển tiếp, chia sẻ.", "Chuyển tiếp khó khăn, mất cân bằng." },
    { "7", "Bảy", "Seven", "Đánh giá lại, kiên trì, thử thách niềm tin.", "Nản chí, thiếu kiên nhẫn." },
    { "8", "Tám", "Eight", "Chuyển động, nỗ lực, thành thạo.", "Mất phương hướng, trì hoãn." },
    { "9", "Chín", "Nine", "Gần đích, độc lập, thành quả.", "Kiệt sức, lo âu, thiếu an toàn." },
    { "10", "Mười", "Ten", "Hoàn tất một chu kỳ, trọn vẹn, gánh nặng.", "Chưa kết thúc, quá tải." },
    { "P", "Thị Đồng", "Page", "Tin tức, tò mò, học hỏi.", "Non nớt, chưa sẵn sàng." },
    { "Kn", "Hiệp Sĩ", "Knight", "Hành động, theo đuổi, nhiệt huyết.", "Bốc đồng, thiếu kiên định." },
    { "Q", "Hoàng Hậu", "Queen", "Nuôi dưỡng, trực giác, làm chủ.", "Phụ thuộc, thiếu tự tin." },
    { "K", "Vua", "King", "Lãnh đạo, kiểm soát, trưởng thành.", "Độc đoán, thiếu kiểm soát." },
}

local CARDS = {}
for i, m in ipairs(MAJOR) do
    CARDS[#CARDS + 1] = {
        kind = "major", mark = ROMAN[i - 1], name = m[1], en = m[2], up = m[3], rev = m[4],
        top = ROMAN[i - 1], bottom = "ẨN CHÍNH",
    }
end
for _, su in ipairs(SUITS) do
    for _, r in ipairs(RANKS) do
        CARDS[#CARDS + 1] = {
            kind = su[3], name = r[2] .. " " .. su[1], en = r[3] .. " of " .. su[2],
            up = r[4], rev = r[5], domain = su[4], top = r[1], bottom = su[5],
        }
    end
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

local function save_history(draws)
    pcall(function()
        local f = io.open(HISTORY, "a")
        if f then
            local parts = {}
            for _, d in ipairs(draws) do
                parts[#parts + 1] = d.card.name .. " (" .. d.card.en .. ")" .. (d.rev and " [ngược]" or "")
            end
            f:write(os.date("%Y-%m-%d %H:%M ") .. table.concat(parts, " | ") .. "\n")
            f:close()
        end
    end)
end

-- ===== màn hình =====
local Tarot = InputContainer:extend{
    name = "vn_tarot",
    covers_fullscreen = true,
    n = 1,
    allow_rev = true,
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
    local aw = math.floor(ah * 0.58)
    if aw > math.floor(W * 0.34) then
        aw = math.floor(W * 0.34)
        ah = math.floor(aw / 0.58)
    end
    card_art(bb, mx, top + 5, aw, ah, c, d.rev)
    local px = mx + aw + 50
    local pw = W - mx - px
    txt(bb, c.name, px, top + 10, 64, { bold = true, max_width = pw })
    txt(bb, c.en, px, top + 88, 32, { color = GRAY5, max_width = pw })
    local ow, oh = self:draw_orient(bb, px, top + 140, d.rev, 30)
    local y = top + 140 + oh + 34
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
    local ah = math.floor((bottom - top) * 0.46)
    local aw = math.floor(ah * 0.58)
    if aw > cw - 40 then
        aw = cw - 40
        ah = math.floor(aw / 0.58)
    end
    for i, d in ipairs(self.draws) do
        local x = mx + (i - 1) * (cw + gap)
        bb:paintBorder(x, top, cw, bottom - top, 3, BLACK, 24)
        txt(bb, labels[i] or "", x + math.floor(cw / 2), top + 12, 26, { center = true, bold = true, color = GRAY5 })
        local ax = x + math.floor((cw - aw) / 2)
        card_art(bb, ax, top + 52, aw, ah, d.card, d.rev)
        local y = top + 52 + ah + 14
        txt(bb, d.card.name, x + math.floor(cw / 2), y, 34, { center = true, bold = true, max_width = cw - 24 })
        y = y + 46
        local ow = math.floor(24 * 4.6)
        self:draw_orient(bb, x + math.floor((cw - ow) / 2), y, d.rev, 24)
        y = y + math.floor(24 * 1.7) + 14
        local tb = TextBoxWidget:new{ text = self:meaning_of(d), face = face(27), width = cw - 44, fgcolor = BLACK }
        if y + tb:getSize().h <= bottom - 8 then tb:paintTo(bb, x + 22, y) end
        tb:free()
    end
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
        if self.shuffling then
            txt(bb, "Đang xáo bài…", math.floor(W / 2), math.floor((top + bottom) / 2) - 40, 56, { center = true, bold = true })
            txt(bb, "Hãy giữ câu hỏi trong đầu", math.floor(W / 2), math.floor((top + bottom) / 2) + 40, 30, { center = true, color = GRAY5 })
        elseif not self.draws then
            txt(bb, "Nghĩ về một câu hỏi, rồi bấm BỐC", math.floor(W / 2), math.floor((top + bottom) / 2) - 50, 52, { center = true, bold = true })
            txt(bb, "78 lá  ·  bốc ngẫu nhiên  ·  có thể ra bài ngược", math.floor(W / 2), math.floor((top + bottom) / 2) + 40, 30, { center = true, color = GRAY5 })
        elseif #self.draws == 1 then
            self:draw_one(bb, x, top, bottom, W, mx)
        else
            self:draw_three(bb, top, bottom, W, mx)
        end
        -- nút
        local list = {
            { "BỐC 1 LÁ", function() self:deal_n(1) end, true, 1.2 },
            { "BỐC 3 LÁ", function() self:deal_n(3) end, true, 1.2 },
            { self.allow_rev and "BÀI NGƯỢC: BẬT" or "BÀI NGƯỢC: TẮT", function()
                self.allow_rev = not self.allow_rev
                UIManager:setDirty(self, "ui")
            end, false, 1.6 },
            { "THOÁT", function() self:close() end, false, 1 },
        }
        local bh, gap = 84, 20
        local by = H - 30 - bh - 22
        local totw = 0
        for _, b in ipairs(list) do totw = totw + b[4] end
        local avail = W - 2 * mx - (#list - 1) * gap
        local bx = mx
        for _, b in ipairs(list) do
            local bw = math.floor(avail * b[4] / totw)
            if b[3] then
                bb:paintRoundedRect(bx, by, bw, bh, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 22, 30, { center = true, bold = true, color = WHITE })
            else
                bb:paintBorder(bx, by, bw, bh, 4, BLACK, 30)
                txt(bb, b[1], bx + math.floor(bw / 2), by + 22, 30, { center = true, bold = true })
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
    UIManager:setDirty(self, "full")
    UIManager:scheduleIn(0.8, function()
        seed()
        self.draws = deal(n, self.allow_rev)
        save_history(self.draws)
        self.shuffling = false
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
