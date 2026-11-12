-- VN Market: bảng điện chứng khoán Việt Nam + tra cứu mã cổ phiếu cho KOReader.
local Blitbuffer = require("ffi/blitbuffer")
local Device = require("device")
local Font = require("ui/font")
local Geom = require("ui/geometry")
local GestureRange = require("ui/gesturerange")
local InputContainer = require("ui/widget/container/inputcontainer")
local InputDialog = require("ui/widget/inputdialog")
local TextWidget = require("ui/widget/textwidget")
local TextBoxWidget = require("ui/widget/textboxwidget")
local UIManager = require("ui/uimanager")
local WidgetContainer = require("ui/widget/container/widgetcontainer")
local Screen = Device.screen

local BLACK = Blitbuffer.COLOR_BLACK
local WHITE = Blitbuffer.COLOR_WHITE

local LOGFILE = "/mnt/us/vn_dash/plugin_log.txt"
local API = "https://iboard-query.ssi.com.vn"

-- ===== cấu hình =====
local PLUGIN_DIR = "."
do
    local src = debug.getinfo(1, "S").source
    local dir = src:match("^@(.*)/[^/]*$")
    if dir then PLUGIN_DIR = dir end
end
local cfg = {
    rotation = 1, interval_trading = 300, interval_idle = 1800,
    watchlist = { "VPS", "FPT", "HPG", "VCB", "SSI", "VND", "MWG", "VNM", "TCB", "MBB" },
    lat = 21.0285, lon = 105.8542, place = "Hà Nội",
    news = {
        { label = "THỜI SỰ", feeds = { "https://vnexpress.net/rss/thoi-su.rss", "https://tuoitre.vn/rss/thoi-su.rss" }, source = "VnExpress", q = "thời sự Việt Nam" },
        { label = "THẾ GIỚI", feeds = { "https://vnexpress.net/rss/the-gioi.rss", "https://tuoitre.vn/rss/the-gioi.rss" }, source = "VnExpress", q = "tin thế giới" },
        { label = "KINH TẾ", feeds = { "https://vnexpress.net/rss/kinh-doanh.rss", "https://tuoitre.vn/rss/kinh-doanh.rss" }, source = "VnExpress", q = "kinh tế Việt Nam" },
        { label = "CHÍNH TRỊ", feeds = { { "https://thanhnien.vn/rss/chinh-tri.rss", "Thanh Niên" }, { "https://vietnamnet.vn/rss/chinh-tri.rss", "VietNamNet" }, { "https://tuoitre.vn/rss/thoi-su.rss", "Tuổi Trẻ" }, { "https://vnexpress.net/rss/thoi-su.rss", "VnExpress" } }, source = "", q = "chính trị Việt Nam" },
    },
}
do
    local ok, c = pcall(dofile, PLUGIN_DIR .. "/config.lua")
    if ok and type(c) == "table" then
        for k, v in pairs(c) do cfg[k] = v end
    end
end

local function log(msg)
    local f = io.open(LOGFILE, "a")
    if f then
        f:write(os.date("%H:%M:%S ") .. tostring(msg) .. "\n")
        f:close()
    end
end

-- ===== danh sách tự chọn (lưu trong /mnt/us/vn_dash/user.txt) =====
local SETFILE = "/mnt/us/vn_dash/user.txt"
cfg.cards = { "VNINDEX", "VN30", "HNX", "UPCOM" }
cfg.autostart = true
local INDEX_MAP = {
    VNINDEX = { "VNINDEX", "VN-Index", true },
    VN30 = { "VN30", "VN30", false },
    HNX = { "HNXIndex", "HNX-Index", true },
    HNXINDEX = { "HNXIndex", "HNX-Index", true },
    UPCOM = { "HNXUpcomIndex", "UPCoM-Index", true },
    HNX30 = { "HNX30", "HNX30", false },
    VN100 = { "VN100", "VN100", false },
    VNALL = { "VNALL", "VNAll", false },
    VNMID = { "VNMIDCAP", "VNMidCap", false },
    VNSML = { "VNSMALLCAP", "VNSmallCap", false },
}
local function words_of(s, maxn)
    local t = {}
    for w in (s or ""):gmatch("[%w]+") do
        t[#t + 1] = w:upper()
        if #t >= maxn then break end
    end
    return t
end
do
    local f = io.open(SETFILE, "r")
    if f then
        for line in f:lines() do
            local k, v = line:match("^(%w+)=(.*)$")
            if k == "watch" then
                local t = words_of(v, 12)
                if #t > 0 then cfg.watchlist = t end
            elseif k == "autostart" then
                cfg.autostart = (v:match("^%s*(%d)") ~= "0")
            elseif k == "cards" then
                local t = words_of(v, 4)
                if #t > 0 then cfg.cards = t end
            end
        end
        f:close()
    end
end
local function save_user()
    local f = io.open(SETFILE, "w")
    if f then
        f:write("watch=" .. table.concat(cfg.watchlist, " ") .. "\n")
        f:write("cards=" .. table.concat(cfg.cards, " ") .. "\n")
        f:write("autostart=" .. (cfg.autostart and "1" or "0") .. "\n")
        f:close()
    end
end

-- ===== tiện ích =====
local function fmt(v, d)
    d = d or 2
    v = tonumber(v) or 0
    local neg = v < 0
    if neg then v = -v end
    local s = string.format("%." .. d .. "f", v)
    local ip, fp = s:match("^(%d+)%.?(%d*)$")
    ip = ip:reverse():gsub("(%d%d%d)", "%1."):reverse()
    ip = ip:gsub("^%.", "")
    local o = ip
    if d > 0 then o = o .. "," .. fp end
    if neg then o = "\226\136\146" .. o end -- dấu trừ −
    return o
end

local function sfmt(v, d)
    local s = fmt(v, d)
    if (tonumber(v) or 0) > 0 then return "+" .. s end
    return s
end

local function fetch(url, tmo)
    local cmd = 'curl -sS -m ' .. tostring(tmo or 14) .. ' --connect-timeout 8 -L -A "Mozilla/5.0" "' .. url .. '" 2>/dev/null'
    local p = io.popen(cmd, "r")
    if not p then return nil end
    local s = p:read("*a")
    p:close()
    if s == nil or s == "" then return nil end
    return s
end

local function fetch_json(url)
    local s = fetch(url)
    if not s then return nil end
    local JSON = require("json")
    local ok, j = pcall(JSON.decode, s)
    if ok and type(j) == "table" then return j end
    return nil
end

local function urlencode(s)
    return (s:gsub("([^%w])", function(c) return string.format("%%%02X", c:byte()) end))
end

local MONTHS = { Jan = 1, Feb = 2, Mar = 3, Apr = 4, May = 5, Jun = 6, Jul = 7, Aug = 8, Sep = 9, Oct = 10, Nov = 11, Dec = 12 }

local function epoch(y, m, d, H, M, S)
    if m <= 2 then y = y - 1 end
    local era = math.floor(y / 400)
    local yoe = y - era * 400
    local mp = (m + 9) % 12
    local doy = math.floor((153 * mp + 2) / 5) + d - 1
    local doe = yoe * 365 + math.floor(yoe / 4) - math.floor(yoe / 100) + doy
    local days = era * 146097 + doe - 719468
    return days * 86400 + H * 3600 + M * 60 + S
end

local function unent(s)
    s = s:gsub("<!%[CDATA%[(.-)%]%]>", "%1")
    s = s:gsub("&quot;", '"')
    s = s:gsub("&apos;", "'")
    s = s:gsub("&#39;", "'")
    s = s:gsub("&#x27;", "'")
    s = s:gsub("&lt;", "<")
    s = s:gsub("&gt;", ">")
    s = s:gsub("&nbsp;", " ")
    s = s:gsub("&amp;", "&")
    return s
end

local function parse_pub(pub)
    if not pub then return "" end
    local dd, mon, yy, hh, mi, ss = pub:match("(%d+) (%a+) (%d+) (%d+):(%d+):(%d+)")
    if not dd or not MONTHS[mon] then return "" end
    local ts = epoch(tonumber(yy), MONTHS[mon], tonumber(dd), tonumber(hh), tonumber(mi), tonumber(ss))
    local sign, th, tm = pub:match("([+-])(%d%d)(%d%d)%s*$")
    if sign then
        local off = tonumber(th) * 3600 + tonumber(tm) * 60
        if sign == "-" then off = -off end
        ts = ts - off
    end
    return os.date("!%H:%M %d/%m", ts + 7 * 3600)
end

local function strip_html(s)
    s = unent(s or "")
    s = s:gsub("<[^>]*>", " ")
    s = unent(s)
    s = s:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", "")
    return s
end

-- tách các <item> của RSS: {title, source, when, desc, link}
local function rss_items(xml, default_source, limit, filter)
    local items = {}
    if not xml then return items end
    for block in xml:gmatch("<item>(.-)</item>") do
        local title = block:match("<title>(.-)</title>")
        if title then
            title = unent(title)
            title = title:gsub("^%s+", ""):gsub("%s+$", "")
            local t, src = title:match("^(.*) %- ([^%-]+)$")
            if not t or default_source ~= "" then t = title; src = default_source end
            local link = block:match("<link>(.-)</link>") or ""
            link = unent(link):gsub("%s+", "")
            local desc = block:match("<description>(.-)</description>") or ""
            if link:find("news.google.com", 1, true) then
                desc = ""
            else
                desc = strip_html(desc)
                if desc:sub(1, #t) == t then desc = desc:sub(#t + 1):gsub("^[%s%p]+", "") end
            end
            local it = { title = t, source = src or "", when = parse_pub(block:match("<pubDate>(.-)</pubDate>")), desc = desc, link = link }
            if not filter or filter(it) then
                items[#items + 1] = it
                if #items >= (limit or 10) then break end
            end
        end
    end
    return items
end

local function fetch_rss(url, default_source, limit)
    local xml = fetch(url)
    if not xml then
        log("rss fail: " .. url)
        return {}
    end
    local items = rss_items(xml, default_source, limit)
    log("rss " .. #items .. " items: " .. url)
    return items
end

local function google_news(query, limit)
    local url = "https://news.google.com/rss/search?q=" .. urlencode(query) .. "&hl=vi&gl=VN&ceid=VN:vi"
    return fetch_rss(url, "", limit)
end


local function load_category(cat)
    for _, f in ipairs(cat.feeds or {}) do
        local url, src = f, cat.source
        if type(f) == "table" then url, src = f[1], f[2] end
        local items = fetch_rss(url, src, 40)
        if #items > 0 then return items end
    end
    return google_news(cat.q .. " when:2d", 30)
end

local WX_TEXT = {
    [0] = "Trời quang", [1] = "Ít mây", [2] = "Mây rải rác", [3] = "Nhiều mây",
    [45] = "Sương mù", [48] = "Sương mù", [51] = "Mưa phùn nhẹ", [53] = "Mưa phùn", [55] = "Mưa phùn dày",
    [56] = "Mưa phùn lạnh", [57] = "Mưa phùn lạnh", [61] = "Mưa nhẹ", [63] = "Mưa vừa", [65] = "Mưa to",
    [66] = "Mưa lạnh", [67] = "Mưa lạnh", [71] = "Tuyết nhẹ", [73] = "Tuyết", [75] = "Tuyết dày", [77] = "Hạt tuyết",
    [80] = "Mưa rào nhẹ", [81] = "Mưa rào", [82] = "Mưa rào lớn", [85] = "Tuyết rào", [86] = "Tuyết rào lớn",
    [95] = "Dông", [96] = "Dông, mưa đá", [99] = "Dông, mưa đá lớn",
}

local function wx_kind(code)
    code = tonumber(code) or 0
    if code == 0 then return "sun" end
    if code == 1 or code == 2 then return "partly" end
    if code == 3 then return "cloud" end
    if code == 45 or code == 48 then return "fog" end
    if code >= 95 then return "storm" end
    if code >= 71 and code <= 77 then return "snow" end
    if code == 85 or code == 86 then return "snow" end
    return "rain"
end

local function aqi_info(v)
    v = tonumber(v) or 0
    if v <= 50 then return "Tốt" end
    if v <= 100 then return "Trung bình" end
    if v <= 150 then return "Kém (nhóm nhạy cảm)" end
    if v <= 200 then return "Xấu" end
    if v <= 300 then return "Rất xấu" end
    return "Nguy hại"
end

local function load_weather()
    local lat, lon = tostring(cfg.lat), tostring(cfg.lon)
    local w = fetch_json("https://api.open-meteo.com/v1/forecast?latitude=" .. lat .. "&longitude=" .. lon ..
        "&current=temperature_2m,relative_humidity_2m,apparent_temperature,weather_code,wind_speed_10m,precipitation" ..
        "&hourly=temperature_2m,precipitation_probability,weather_code&forecast_hours=24" ..
        "&daily=weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max" ..
        "&timezone=Asia%2FBangkok&forecast_days=5")
    local a = fetch_json("https://air-quality-api.open-meteo.com/v1/air-quality?latitude=" .. lat .. "&longitude=" .. lon ..
        "&current=us_aqi,pm2_5,pm10&timezone=Asia%2FBangkok")
    if not w or not w.current then
        log("weather fail")
        return nil
    end
    return { w = w, a = a and a.current }
end

local function load_index(id)
    local j = fetch_json(API .. "/exchange-index/" .. id .. "?hasHistory=true")
    local d = j and j.data
    if type(d) ~= "table" or not d.indexValue then return nil end
    local hist = {}
    if type(d.history) == "table" then
        for _, p in ipairs(d.history) do
            if p.indexValue then hist[#hist + 1] = p.indexValue end
        end
    end
    local change = d.change or 0
    return {
        value = d.indexValue,
        prev = d.prevIndexValue or (d.indexValue - change),
        change = change,
        pct = d.changePercent or 0,
        adv = d.advances or 0,
        dec = d.declines or 0,
        unch = d.nochanges or 0,
        val = (d.allValue or 0) / 1e9,
        fbuy = d.totalBuyForeignQtty,
        fsell = d.totalSellForeignQtty,
        hist = hist,
    }
end

-- ===== phần mở rộng: tải song song, danh mục, top mã, vàng, lịch =====
local function decode(s)
    if not s or s == "" then return nil end
    local JSON = require("json")
    local ok, j = pcall(JSON.decode, s)
    if ok and type(j) == "table" then return j end
    return nil
end

local function fetch_many(urls)
    os.execute("mkdir -p /tmp/vnm")
    local parts = {}
    for i, u in ipairs(urls) do
        parts[#parts + 1] = 'curl -sS -m 20 --connect-timeout 8 -L -A "Mozilla/5.0" "' .. u .. '" -o /tmp/vnm/' .. i .. '.out 2>/dev/null &'
    end
    parts[#parts + 1] = "wait"
    os.execute(table.concat(parts, "\n"))
    local res = {}
    for i = 1, #urls do
        local f = io.open("/tmp/vnm/" .. i .. ".out", "r")
        if f then
            res[i] = f:read("*a")
            f:close()
        end
        os.remove("/tmp/vnm/" .. i .. ".out")
    end
    return res
end

local function fetch_news(sym)
    local urls = {
        "https://vnexpress.net/rss/kinh-doanh.rss",
        "https://tuoitre.vn/rss/kinh-doanh.rss",
        "https://cafef.vn/thi-truong-chung-khoan.rss",
        "https://vietnamnet.vn/rss/kinh-doanh.rss",
        "https://news.google.com/rss/search?q=" .. urlencode(sym .. " cổ phiếu when:7d") .. "&hl=vi&gl=VN&ceid=VN:vi",
    }
    local raws = fetch_many(urls)
    local pat = "%f[%w]" .. sym .. "%f[%W]"
    local function match(it) return (it.title .. " " .. (it.desc or "")):find(pat) end
    local srcs = { "VnExpress", "Tuổi Trẻ", "CafeF", "VietNamNet" }
    local out, seen = {}, {}
    for i = 1, 4 do
        for _, it in ipairs(rss_items(raws[i], srcs[i], 40, match)) do
            if not seen[it.title] and #out < 8 then
                seen[it.title] = true
                out[#out + 1] = it
            end
        end
    end
    for _, it in ipairs(rss_items(raws[5], "", 8)) do
        if not seen[it.title] and #out < 8 then
            seen[it.title] = true
            out[#out + 1] = it
        end
    end
    log("stock news " .. sym .. ": " .. #out)
    return out
end

local function walk(t, fn, key, depth)
    depth = depth or 0
    if depth > 7 then return end
    if type(t) == "table" then
        for k, v in pairs(t) do walk(v, fn, k, depth + 1) end
    else
        fn(key, t)
    end
end

-- hồ sơ doanh nghiệp tóm gọn (ngành · làm gì/bán gì · điểm dễ nhớ) cho các mã phổ biến
local PROFILES = {
    VPS = { "Hoá chất nông nghiệp", "Sản xuất và phân phối thuốc bảo vệ thực vật (thuốc trừ sâu, trừ cỏ, diệt nấm) và phân bón cho nông dân.", "Mã VPS dễ bị nhầm với Công ty Chứng khoán VPS, nhưng đây là một doanh nghiệp thuốc sát trùng, hoàn toàn khác." },
    VCB = { "Ngân hàng", "Ngân hàng thương mại do nhà nước chi phối, mạnh về thanh toán quốc tế, ngoại hối và khách hàng doanh nghiệp lớn.", "Thuộc nhóm 'Big 4' quốc doanh, thường dẫn đầu về lợi nhuận và vốn hoá toàn ngành ngân hàng." },
    BID = { "Ngân hàng", "BIDV cho vay doanh nghiệp, hạ tầng và bất động sản; có quy mô tài sản thuộc nhóm lớn nhất hệ thống.", "Một trong 'Big 4' ngân hàng quốc doanh cùng VCB, CTG, Agribank." },
    CTG = { "Ngân hàng", "VietinBank, mạng lưới rộng, cho vay doanh nghiệp lớn và dịch vụ thanh toán cho khách hàng nhà nước.", "Một trong 'Big 4' ngân hàng quốc doanh." },
    TCB = { "Ngân hàng", "Techcombank, ngân hàng tư nhân mạnh về khách hàng khá giả, bất động sản và trái phiếu; tiền gửi không kỳ hạn (CASA) cao.", "Tên viết tắt từ 'Technological': hay được nhắc đến như ngân hàng đi đầu về công nghệ." },
    MBB = { "Ngân hàng", "MB (Ngân hàng Quân đội): cho vay doanh nghiệp, bán lẻ; có chứng khoán MBS, bảo hiểm MB Ageas Life và app MB Bank rất phổ biến.", "Xuất phát từ khối quân đội, app MB Bank có lượng người dùng thanh toán rất lớn." },
    VPB = { "Ngân hàng", "VPBank, mạnh cho vay tiêu dùng (qua FE Credit), vay mua xe và doanh nghiệp nhỏ và vừa.", "Tập đoàn SMBC của Nhật là cổ đông chiến lược lớn." },
    ACB = { "Ngân hàng", "Ngân hàng Á Châu, thiên về khách hàng cá nhân và doanh nghiệp nhỏ; nổi tiếng quản trị thận trọng, nợ xấu thấp.", "Thường được xem là ngân hàng tư nhân 'an toàn' và ổn định." },
    STB = { "Ngân hàng", "Sacombank, ngân hàng tư nhân lớn tại TP.HCM với mạng lưới chi nhánh dày.", "Nổi tiếng với giai đoạn tái cơ cấu kéo dài nhiều năm." },
    HDB = { "Ngân hàng", "HDBank, cho vay bán lẻ và doanh nghiệp nhỏ; có công ty tài chính HD Saison và gắn với hệ sinh thái Vietjet.", "Có liên hệ chặt chẽ với bà Nguyễn Thị Phương Thảo (Vietjet)." },
    TPB = { "Ngân hàng", "TPBank, tập trung ngân hàng số và dịch vụ cho khách hàng trẻ.", "Nổi tiếng với 'ATM gạo' và các máy LiveBank giao dịch tự động." },
    VIB = { "Ngân hàng", "VIB, mạnh về cho vay mua ô tô và bán lẻ.", "Hay được nhắc đến với vay mua xe và thẻ tín dụng." },
    SHB = { "Ngân hàng", "SHB, ngân hàng tư nhân cỡ lớn có trụ sở Hà Nội; có công ty tài chính riêng.", "Từng sáp nhập Habubank." },
    SSI = { "Chứng khoán", "Công ty chứng khoán hàng đầu: môi giới, tự doanh, tư vấn và ngân hàng đầu tư.", "Bảng giá iBoard của SSI chính là nguồn dữ liệu mà app này đang dùng." },
    VND = { "Chứng khoán", "VNDirect, môi giới chứng khoán với lượng lớn nhà đầu tư cá nhân.", "Mạnh về giao dịch trực tuyến cho nhà đầu tư nhỏ lẻ." },
    VCI = { "Chứng khoán", "Vietcap (Bản Việt), môi giới và ngân hàng đầu tư, mạnh về khách hàng tổ chức.", "Thường được nhắc đến cùng nhóm công ty chứng khoán top đầu." },
    HCM = { "Chứng khoán", "HSC, một trong những công ty chứng khoán lâu đời tại TP.HCM.", "Là một trong những công ty chứng khoán ra đời sớm nhất thị trường." },
    VIX = { "Chứng khoán", "Chứng khoán VIX, môi giới và đầu tư, thuộc nhóm có vốn lớn.", "Nằm trong nhóm cổ phiếu chứng khoán có vốn hoá cao." },
    SHS = { "Chứng khoán", "Chứng khoán Sài Gòn - Hà Nội, môi giới và đầu tư.", "Liên quan đến ngân hàng SHB." },
    MBS = { "Chứng khoán", "Chứng khoán MB, công ty thành viên của MB.", "Thuộc hệ sinh thái MB Bank." },
    BVH = { "Bảo hiểm", "Tập đoàn Bảo Việt: bảo hiểm nhân thọ, phi nhân thọ và đầu tư.", "Thương hiệu bảo hiểm lâu đời, có từ thập niên 1960." },
    VHM = { "Bất động sản", "Vinhomes phát triển các đại đô thị nhà ở như Ocean Park, Grand Park, Smart City.", "Thuộc hệ sinh thái Vingroup; thường dẫn đầu vốn hoá toàn thị trường." },
    VIC = { "Tập đoàn đa ngành", "Vingroup: bất động sản (Vinhomes), ô tô điện VinFast, y tế Vinmec, giáo dục Vinschool/VinUni.", "Của ông Phạm Nhật Vượng; VinFast đã niêm yết trên sàn Mỹ." },
    VRE = { "Bất động sản thương mại", "Vincom Retail vận hành các trung tâm thương mại Vincom trên cả nước.", "Chuỗi trung tâm thương mại quen thuộc ở nhiều thành phố." },
    NVL = { "Bất động sản", "Novaland phát triển nhà ở và nghỉ dưỡng như NovaWorld Phan Thiết, Aqua City.", "Nổi tiếng giai đoạn chịu áp lực nợ và trái phiếu những năm 2022-2023." },
    KDH = { "Bất động sản", "Khang Điền phát triển nhà phố, biệt thự và căn hộ chủ yếu ở TP.HCM.", "Được biết đến với mảng nhà phố, biệt thự khu Đông." },
    DXG = { "Bất động sản", "Đất Xanh Group, môi giới và phát triển bất động sản.", "Tên gắn với dịch vụ môi giới bất động sản lớn." },
    NLG = { "Bất động sản", "Nam Long phát triển khu đô thị, căn hộ tầm trung, hợp tác với đối tác Nhật Bản.", "Dự án Izumi City ở Đồng Nai là dự án tiêu biểu." },
    KBC = { "Khu công nghiệp", "Kinh Bắc (KBC) phát triển và cho thuê đất khu công nghiệp ở miền Bắc và miền Nam.", "Khu công nghiệp Quế Võ, Tràng Duệ là các dự án tiêu biểu." },
    BCM = { "Khu công nghiệp", "Becamex IDC phát triển khu công nghiệp và đô thị ở Bình Dương và Bình Phước.", "Gắn với khu công nghiệp VSIP." },
    IDC = { "Khu công nghiệp", "IDICO, phát triển khu công nghiệp, điện, và hạ tầng.", "Doanh nghiệp khu công nghiệp ở phía Nam." },
    SZC = { "Khu công nghiệp", "Sonadezi Châu Đức, khu công nghiệp và hạ tầng ở Bà Rịa - Vũng Tàu.", "Thuộc hệ sinh thái Sonadezi Đồng Nai." },
    HPG = { "Thép", "Hòa Phát: tập đoàn thép lớn nhất Việt Nam (khu liên hợp Dung Quất, Hải Dương), thêm nông nghiệp và ống thép.", "Của ông Trần Đình Long; cổ phiếu có rất nhiều nhà đầu tư cá nhân." },
    HSG = { "Thép", "Tập đoàn Hoa Sen: tôn mạ, ống thép và vật liệu xây dựng.", "Thương hiệu tôn Hoa Sen quen thuộc ở cửa hàng vật liệu xây dựng." },
    NKG = { "Thép", "Nam Kim: tôn mạ màu, tôn mạ kẽm, ống thép.", "Tôn mạ xuất khẩu nhiều thị trường." },
    MWG = { "Bán lẻ", "Thế Giới Di Động: bán điện thoại, điện máy (TGDĐ, Điện Máy Xanh) và thực phẩm tại Bách Hoá Xanh.", "Bách Hoá Xanh từng lỗ nhiều năm rồi mới quay lại có lãi." },
    FRT = { "Bán lẻ", "FPT Retail: chuỗi FPT Shop (điện thoại, laptop) và nhà thuốc Long Châu.", "Long Châu là chuỗi nhà thuốc lớn bậc nhất cả nước." },
    PNJ = { "Bán lẻ trang sức", "Phú Nhuận Jewelry bán vàng, bạc, trang sức và vàng miếng qua chuỗi cửa hàng PNJ.", "Giá vàng PNJ cũng có trên tab VÀNG của app này." },
    DGW = { "Phân phối công nghệ", "Digiworld phân phối điện thoại, laptop và thiết bị công nghệ của nhiều hãng.", "Phân phối sản phẩm Xiaomi ở Việt Nam." },
    VNM = { "Thực phẩm - sữa", "Vinamilk: sữa tươi, sữa bột, sữa chua, sữa đặc và đồ uống.", "Công ty sữa lớn nhất Việt Nam, sản phẩm có mặt ở hầu hết gia đình." },
    MSN = { "Tiêu dùng - bán lẻ", "Masan: nước mắm Chinsu, Nam Ngư, mì Omachi; chuỗi WinMart; khoáng sản vonfram.", "Của ông Nguyễn Đăng Quang." },
    SAB = { "Đồ uống", "Sabeco sản xuất bia Sài Gòn, bia 333.", "Bia Sài Gòn và 333 là thương hiệu bia quen thuộc." },
    KDC = { "Thực phẩm", "Kido: kem Merino, bánh Kinh Đô, dầu ăn Tường An.", "Gắn với kem Merino và bánh trung thu Kinh Đô." },
    SBT = { "Đường", "Thành Thành Công - Biên Hòa: trồng mía và sản xuất đường.", "Một trong các nhà sản xuất đường lớn." },
    QNS = { "Đường - sữa đậu nành", "Đường Quảng Ngãi: đường và sữa đậu nành Fami.", "Thương hiệu sữa đậu nành Fami." },
    DBC = { "Nông nghiệp", "Dabaco: thức ăn chăn nuôi, heo giống và thịt heo.", "Gắn với giá heo hơi." },
    HAG = { "Nông nghiệp", "Hoàng Anh Gia Lai: trồng chuối, cây ăn trái và chăn nuôi heo.", "Từng nổi tiếng với bất động sản và bóng đá." },
    FPT = { "Công nghệ", "FPT: phần mềm xuất khẩu (nhiều khách Nhật), viễn thông (Internet FPT), giáo dục (ĐH FPT).", "Của ông Trương Gia Bình; thường là mã công nghệ vốn hoá lớn nhất." },
    CMG = { "Công nghệ", "CMC: phần mềm, chuyển đổi số và dịch vụ công nghệ thông tin.", "Một trong các tập đoàn công nghệ lớn trong nước." },
    VGI = { "Viễn thông", "Viettel Global đầu tư viễn thông ở nước ngoài (Mytel, Movitel...).", "Là Viettel Global, thuộc Viettel." },
    GAS = { "Dầu khí", "PV Gas: thu gom, vận chuyển và phân phối khí, LPG.", "Doanh nghiệp nhà nước vốn hoá lớn." },
    PLX = { "Xăng dầu", "Petrolimex: bán xăng dầu qua chuỗi cây xăng lớn nhất cả nước.", "Cây xăng quen thuộc khắp nơi." },
    PVD = { "Dầu khí", "PV Drilling: giàn khoan và dịch vụ khoan dầu khí.", "Giá dầu ảnh hưởng mạnh tới cổ phiếu." },
    PVS = { "Dầu khí", "PTSC: dịch vụ kỹ thuật dầu khí, cơ khí và giàn khoan.", "Gắn với các công trình dầu khí ngoài khơi." },
    BSR = { "Lọc dầu", "Lọc hoá dầu Bình Sơn vận hành nhà máy lọc dầu Dung Quất.", "Nhà máy lọc dầu Dung Quất ở Quảng Ngãi." },
    OIL = { "Xăng dầu", "PVOIL bán xăng dầu qua hệ thống cây xăng.", "Thuộc nhóm dầu khí." },
    POW = { "Điện", "PV Power: nhiệt điện khí, than và thuỷ điện.", "Nhà máy Nhơn Trạch là tên quen thuộc." },
    REE = { "Cơ điện - điện nước", "REE: cơ điện lạnh, điều hoà và đầu tư điện, nước.", "Thương hiệu điều hoà Reetech." },
    NT2 = { "Điện", "Nhiệt điện Nhơn Trạch 2 chạy khí.", "Nhà máy điện khí." },
    GEG = { "Điện tái tạo", "Điện Gia Lai: điện gió, điện mặt trời và thuỷ điện.", "Điện mặt trời, điện gió." },
    VJC = { "Hàng không", "Vietjet: hãng bay giá rẻ nội địa và quốc tế.", "Thuộc nhóm hàng không do bà Nguyễn Thị Phương Thảo sáng lập." },
    HVN = { "Hàng không", "Vietnam Airlines: hãng hàng không quốc gia, dịch vụ đủ hạng.", "Hãng bay quốc gia, thành viên SkyTeam." },
    GMD = { "Cảng biển", "Gemadept: khai thác cảng, logistics và cảng nước sâu Gemalink.", "Cảng Gemalink ở Cái Mép." },
    HAH = { "Vận tải biển", "Hải An: vận tải container, cảng và logistics.", "Chạy tuyến container nội địa và quốc tế." },
    VSC = { "Cảng biển", "Container Việt Nam: khai thác cảng và dịch vụ container.", "Khai thác cảng ở Hải Phòng." },
    VHC = { "Thuỷ sản", "Vĩnh Hoàn: nuôi, chế biến và xuất khẩu cá tra, kèm collagen.", "Nhà xuất khẩu cá tra lớn." },
    ANV = { "Thuỷ sản", "Nam Việt: chế biến và xuất khẩu cá tra.", "Gắn với giá cá tra." },
    DGC = { "Hoá chất", "Đức Giang: photpho vàng, axit photphoric và hoá chất công nghiệp.", "Tăng trưởng nhờ photpho vàng." },
    DPM = { "Phân bón", "Đạm Phú Mỹ: sản xuất phân đạm urê.", "Nhà máy đạm ở Bà Rịa - Vũng Tàu." },
    DCM = { "Phân bón", "Đạm Cà Mau: sản xuất phân đạm urê.", "Nhà máy đạm ở Cà Mau." },
    GVR = { "Cao su", "Tập đoàn Cao su: cao su thiên nhiên và cho thuê đất khu công nghiệp.", "Giữ nhiều đất cao su có tiềm năng làm khu công nghiệp." },
    PHR = { "Cao su", "Cao su Phước Hòa và khu công nghiệp.", "Vùng cao su Bình Dương." },
    DRC = { "Lốp xe", "Cao su Đà Nẵng: sản xuất lốp xe máy, ô tô và xe tải.", "Thương hiệu lốp DRC." },
    DHG = { "Dược phẩm", "Dược Hậu Giang: thuốc Hapacol và nhiều sản phẩm dược.", "Hapacol quen thuộc ở nhà thuốc." },
    IMP = { "Dược phẩm", "Imexpharm: thuốc kháng sinh và thuốc kê đơn.", "Doanh nghiệp dược mạnh về kháng sinh." },
    TRA = { "Dược phẩm", "Traphaco: thuốc từ dược liệu.", "Hoạt huyết dưỡng não là thuốc quen thuộc." },
    VCG = { "Xây dựng", "Vinaconex: xây dựng, hạ tầng và bất động sản.", "Doanh nghiệp xây dựng nhà nước." },
    CTD = { "Xây dựng", "Coteccons: tổng thầu nhà cao tầng và công trình lớn.", "Tên tuổi tổng thầu xây dựng." },
    HBC = { "Xây dựng", "Xây dựng Hoà Bình: tổng thầu nhà cao tầng.", "Từng có nhiều dự án lớn." },
    TNG = { "Dệt may", "TNG: gia công may mặc xuất khẩu.", "Đơn hàng xuất khẩu đi Mỹ, châu Âu." },
    MSH = { "Dệt may", "May Sông Hồng: may mặc xuất khẩu.", "May mặc xuất khẩu và thời trang." },
    TCM = { "Dệt may", "Dệt may Thành Công: sợi, vải và quần áo.", "Gắn với chuỗi dệt may xuất khẩu." },
    PVT = { "Vận tải dầu khí", "PVTrans: vận tải dầu thô và sản phẩm dầu bằng đường biển.", "Đội tàu chở dầu." },
    SCS = { "Logistics", "Dịch vụ Hàng hoá Sài Gòn: kho hàng hoá ở sân bay Tân Sơn Nhất.", "Kho hàng không Tân Sơn Nhất." },
}

local INDEX_INFO = {
    ["VN-Index"] = {
        { "Là gì", "Chỉ số đại diện cho toàn bộ cổ phiếu niêm yết trên sàn HOSE (TP.HCM), tính theo vốn hoá nên các mã lớn có ảnh hưởng nhiều nhất." },
        { "Cách đọc", "Tăng nghĩa là phần lớn các mã vốn hoá lớn tăng. Xem thêm số mã tăng/giảm và giá trị giao dịch để biết dòng tiền mạnh hay yếu." },
        { "Dễ nhớ", "Bắt đầu từ 100 điểm vào ngày 28/7/2000, ngày phiên giao dịch đầu tiên của sàn TP.HCM." },
    },
    ["VN30"] = {
        { "Là gì", "Rổ 30 cổ phiếu vốn hoá lớn và thanh khoản tốt nhất sàn HOSE, được xem xét lại định kỳ." },
        { "Cách đọc", "Phản ánh nhóm cổ phiếu 'bluechip'; thường biến động giống VN-Index nhưng mạnh hơn khi nhóm trụ cột đổi chiều." },
        { "Dễ nhớ", "Là cơ sở của hợp đồng tương lai VN30 trên thị trường phái sinh." },
    },
    ["HNX-Index"] = {
        { "Là gì", "Chỉ số cổ phiếu niêm yết trên sàn HNX (Hà Nội), có nhiều doanh nghiệp vừa và nhỏ hơn HOSE." },
        { "Cách đọc", "Giá trị thấp hơn nhiều so với VN-Index vì khác cách tính và quy mô vốn hoá." },
        { "Dễ nhớ", "Biên độ dao động trong ngày là ±10%, rộng hơn HOSE (±7%)." },
    },
    ["UPCoM-Index"] = {
        { "Là gì", "Chỉ số của thị trường UPCoM, nơi giao dịch cổ phiếu công ty đại chúng chưa niêm yết." },
        { "Cách đọc", "Thanh khoản thường thấp và biến động mạnh theo từng mã nhỏ." },
        { "Dễ nhớ", "Biên độ ±15%; thị trường bắt đầu hoạt động từ 24/6/2009." },
    },
    ["HNX30"] = { { "Là gì", "Rổ 30 cổ phiếu vốn hoá lớn và thanh khoản tốt nhất sàn HNX." } },
    ["VN100"] = { { "Là gì", "Rổ 100 cổ phiếu vốn hoá lớn nhất sàn HOSE, gồm VN30 và nhóm vốn hoá vừa." } },
}

local INDEX_TAG = {
    ["VN-Index"] = "Toàn sàn HOSE", ["VN30"] = "30 mã lớn nhất HOSE", ["HNX-Index"] = "Sàn Hà Nội",
    ["UPCoM-Index"] = "Chưa niêm yết", ["HNX30"] = "30 mã lớn HNX", ["VN100"] = "100 mã lớn HOSE",
}


local function name_core(nm)
    nm = nm or ""
    for _, pre in ipairs({ "Công ty Cổ phần ", "Công ty cổ phần ", "Công ty TNHH ", "Tập đoàn ", "Ngân hàng Thương mại Cổ phần ", "Ngân hàng TMCP ", "Tổng Công ty ", "Chứng khoán " }) do
        if nm:sub(1, #pre) == pre then nm = nm:sub(#pre + 1) end
    end
    return nm
end

-- hồ sơ doanh nghiệp: ngành + mô tả (thử nhiều nguồn, dò khoá linh hoạt)
local function load_profile(sym, d)
    local urls = {
        "https://finfo-api.vndirect.com.vn/v4/company_profiles?q=code:" .. sym,
        "https://finfo-api.vndirect.com.vn/v4/stocks?q=code:" .. sym .. "&size=1",
        "https://iboard-api.ssi.com.vn/statistics/company/company-profile?symbol=" .. sym .. "&language=vn",
    }
    local raws = fetch_many(urls)
    for i = 1, 3 do log("profile" .. i .. " " .. sym .. ": " .. tostring(raws[i] and raws[i]:gsub("%s+", " "):sub(1, 500))) end
    local industry, best, bestscore = nil, nil, 0
    for i = 1, 3 do
        local j = decode(raws[i])
        if j then
            walk(j, function(k, v)
                if type(v) ~= "string" or type(k) ~= "string" then return end
                local kl = k:lower()
                if not industry and v ~= "" and #v < 90 and (kl:find("industry") or kl:find("icb") or kl:find("sector") or kl:find("nganh"))
                    and not kl:find("code") and not kl:find("eng") and not kl:find("id") then
                    industry = v
                end
                if #v > 80 and not kl:find("risk") and not kl:find("eng") then
                    local score = #v
                    if kl:find("overview") or kl:find("business") or kl:find("intro") or kl:find("profile") or kl:find("description") or kl:find("history") then
                        score = score + 100000
                    end
                    if score > bestscore then
                        best = v
                        bestscore = score
                    end
                end
            end)
        end
    end
    local src = "nguồn VNDirect/SSI"
    if not best and d and d.companyNameVi then
        local url = "https://vi.wikipedia.org/w/api.php?action=query&generator=search&gsrsearch=" .. urlencode(d.companyNameVi) ..
            "&gsrlimit=1&prop=extracts&exintro=1&explaintext=1&exchars=700&format=json"
        local j = decode(fetch(url, 14))
        local pages = j and j.query and j.query.pages
        if type(pages) == "table" then
            for _, p in pairs(pages) do
                if type(p) == "table" and type(p.extract) == "string" and p.extract ~= "" then
                    local core = name_core(d.companyNameVi):lower()
                    if #core >= 3 and p.extract:lower():find(core, 1, true) then
                        best = p.extract
                        src = "Wikipedia"
                    end
                end
            end
        end
        log("profile wiki " .. sym .. ": " .. tostring(best and #best))
    end
    if best then best = strip_html(best) end
    return { industry = industry, text = best, src = src }
end

local function parse_index(j)
    local d = j and j.data
    if type(d) ~= "table" or not d.indexValue then return nil end
    local hist = {}
    if type(d.history) == "table" then
        for _, p in ipairs(d.history) do
            if p.indexValue then hist[#hist + 1] = p.indexValue end
        end
    end
    local change = d.change or 0
    return {
        value = d.indexValue,
        prev = d.prevIndexValue or (d.indexValue - change),
        change = change,
        pct = d.changePercent or 0,
        adv = d.advances or 0,
        dec = d.declines or 0,
        unch = d.nochanges or 0,
        val = (d.allValue or 0) / 1e9,
        fbuy = d.totalBuyForeignQtty,
        fsell = d.totalSellForeignQtty,
        hist = hist,
    }
end

local function parse_stock_row(d)
    local ref = d.refPrice or 0
    local price = d.matchedPrice
    if not price or price == 0 then price = ref + (d.priceChange or 0) end
    if price == 0 then price = ref end
    local change = d.priceChange or (price - ref)
    return {
        sym = d.stockSymbol, price = price, ref = ref, change = change,
        pct = d.priceChangePercent or 0, value = d.nmTotalTradedValue or 0, vol = d.nmTotalTradedQty or 0,
    }
end

local function stock_item(sym, raw)
    local j = decode(raw)
    local d = j and j.data
    if type(d) ~= "table" or not d.stockSymbol then
        return { id = sym, name = sym, sym = sym, data = nil }
    end
    local r = parse_stock_row(d)
    local ref = r.ref
    return {
        id = sym, sym = sym,
        name = sym .. " · " .. string.upper(d.exchange or ""),
        stock = {
            price = r.price, ref = ref, floor = d.floor or ref * 0.93, ceiling = d.ceiling or ref * 1.07,
            open = d.openPrice, high = d.highest, low = d.lowest, vol = d.nmTotalTradedQty or 0, val = r.value,
        },
        data = { value = r.price / 1000, prev = ref / 1000, change = r.change / 1000, pct = r.pct, hist = {}, adv = 0, dec = 0, unch = 0, val = r.value / 1e9 },
    }
end

local function load_watch()
    local urls = {}
    for i, s in ipairs(cfg.watchlist) do urls[i] = API .. "/stock/" .. s end
    local raws = fetch_many(urls)
    local out = {}
    for i, s in ipairs(cfg.watchlist) do
        local j = decode(raws[i])
        local d = j and j.data
        if type(d) == "table" and d.stockSymbol then
            out[#out + 1] = parse_stock_row(d)
        else
            out[#out + 1] = { sym = s, missing = true }
        end
    end
    return out
end

local function top_n(rows, filter, cmp, n)
    local t = {}
    for _, r in ipairs(rows) do
        if filter(r) then t[#t + 1] = r end
    end
    table.sort(t, cmp)
    local out = {}
    for i = 1, math.min(n, #t) do out[i] = t[i] end
    return out
end

local SECTORS = {
    { "Ngân hàng", "VCB BID CTG TCB MBB VPB ACB STB HDB TPB SHB LPB MSB OCB EIB VIB SSB NAB BAB ABB KLB BVB VAB PGB SGB" },
    { "Chứng khoán", "SSI VND HCM VCI SHS MBS FTS BSI CTS AGR VIX ORS TVS BVS VDS APS DSE WSS HAC SBS VFS TCI EVS IVS ART BMS" },
    { "Bảo hiểm", "BVH BMI MIG PVI VNR PTI ABI BIC PRE" },
    { "Bất động sản", "VHM VIC VRE NVL KDH DXG DIG CEO PDR NLG HDG HDC TCH SCR NTL LDG QCG VPI AGG CRE ITC NBB DXS TDC HQC KHG SJS API CKG NHA HAR IJC ASM SZL" },
    { "BĐS khu công nghiệp", "KBC IDC SZC VGC SIP BCM NTC ITA SNZ D2D IDV LHG" },
    { "Thép", "HPG HSG NKG SMC TLH POM VGS TVN VIS" },
    { "Xây dựng & VLXD", "VCG CTD HBC FCN LCG HHV C4G CII KSB DHA HT1 BCC VLB CTI CTR VCS PHC" },
    { "Dầu khí", "GAS PLX PVD PVS BSR OIL PVC PVB PGC PGD PGS CNG ASP" },
    { "Điện & tiện ích", "POW REE NT2 GEG HND QTP PPC BWE TDM TDW VSH CHP TMP SBA PC1 TTA DNH" },
    { "Bán lẻ", "MWG PNJ FRT DGW PET" },
    { "Thực phẩm & đồ uống", "VNM MSN SAB KDC SBT QNS DBC LTG BAF PAN HAG HNG TAR" },
    { "Thuỷ sản", "VHC ANV FMC IDI MPC CMX ACL" },
    { "Công nghệ & viễn thông", "FPT CMG ELC ITD VGI FOX" },
    { "Hoá chất & phân bón", "DGC DPM DCM CSV LAS BFC DDV NTP BMP AAA APH" },
    { "Vận tải & logistics", "HVN VJC GMD VSC HAH VOS VTO PVT PHP SGP HTV TCL SCS" },
    { "Y tế & dược", "DHG IMP TRA DBD DMC DVN PME OPC AMV" },
    { "Dệt may", "TNG GIL MSH TCM STK VGT ADS" },
    { "Cao su & lốp", "GVR PHR DPR DRC CSM SRC TNC TRC" },
}
local SECTOR_OF = {}
for _, s in ipairs(SECTORS) do
    for sym in s[2]:gmatch("%S+") do SECTOR_OF[sym] = s[1] end
end
if type(cfg.sector_extra) == "table" then
    for sym, name in pairs(cfg.sector_extra) do SECTOR_OF[sym] = name end
end

local function load_top()
    local raw = fetch(API .. "/stock/exchange/hose", 45)
    local j = decode(raw)
    local arr = j and j.data
    if type(arr) ~= "table" then
        log("top fail")
        return nil
    end
    local rows = {}
    for _, d in ipairs(arr) do
        if type(d) == "table" and d.stockSymbol and (d.stockType == nil or d.stockType == "s") then
            local r = parse_stock_row(d)
            r.net = ((d.buyForeignValue or 0) - (d.sellForeignValue or 0)) / 1e9
            rows[#rows + 1] = r
        end
    end
    log("top rows: " .. #rows)
    -- gom theo nhóm ngành
    local acc, tv, tq = {}, 0, 0
    for _, r in ipairs(rows) do
        local sname = SECTOR_OF[r.sym]
        if sname then
            local a = acc[sname]
            if not a then
                a = { name = sname, value = 0, vol = 0, n = 0, adv = 0, dec = 0, net = 0, ws = 0, wb = 0, rows = {} }
                acc[sname] = a
            end
            a.rows[#a.rows + 1] = r
            a.value = a.value + r.value
            a.vol = a.vol + r.vol
            a.n = a.n + 1
            if r.change > 0 then a.adv = a.adv + 1 elseif r.change < 0 then a.dec = a.dec + 1 end
            a.net = a.net + r.net
            a.ws = a.ws + r.pct * r.value
            a.wb = a.wb + r.value
            if not a.best or r.value > a.best.value then a.best = r end
            tv = tv + r.value
            tq = tq + r.vol
        end
    end
    local sectors = {}
    for _, a in pairs(acc) do
        a.pct = (a.wb > 0) and (a.ws / a.wb) or 0
        a.score = (tv > 0 and a.value / tv or 0) + (tq > 0 and a.vol / tq or 0)
        a.share = (tv > 0) and (a.value / tv) or 0
        table.sort(a.rows, function(x, y) return x.value > y.value end)
        sectors[#sectors + 1] = a
    end
    return {
        gain = top_n(rows, function(r) return r.pct > 0 and r.value >= 5e9 end, function(a, b) return a.pct > b.pct end, 10),
        lose = top_n(rows, function(r) return r.pct < 0 and r.value >= 5e9 end, function(a, b) return a.pct < b.pct end, 10),
        fbuy = top_n(rows, function(r) return r.net > 0 end, function(a, b) return a.net > b.net end, 10),
        fsell = top_n(rows, function(r) return r.net < 0 end, function(a, b) return a.net < b.net end, 10),
        sectors = sectors,
        rows = rows,
        mapped = #rows,
    }
end

-- ----- vàng -----
local function parse_num(v)
    if type(v) == "number" then return v end
    if type(v) ~= "string" then return nil end
    local dec = v:match("^%s*(%d+%.%d%d?)%s*$")
    if dec then return tonumber(dec) end
    local d = v:gsub("[^%d]", "")
    if d == "" then return nil end
    return tonumber(d)
end

-- chuẩn hoá về triệu đồng/lượng (đoán đơn vị theo độ lớn)
local function to_trieu(v)
    v = parse_num(v)
    if not v or v <= 0 then return nil end
    for _, f in ipairs({ 1e6, 1e5, 1e4, 1e3, 100, 10, 1 }) do
        local x = v / f
        if x >= 20 and x <= 400 then return x end
    end
    return nil
end

local function attrs_of(tag)
    local a = {}
    for k, v in tag:gmatch('([%w_@]+)%s*=%s*"(.-)"') do a[k] = v end
    return a
end

local function add_rows(rows, src, list, maxn)
    local seen = 0
    for _, e in ipairs(list) do
        if seen >= maxn then break end
        local b, s = to_trieu(e.buy), to_trieu(e.sell)
        if e.name and (b or s) then
            rows[#rows + 1] = { src = src, unit = "triệu đồng/lượng", name = e.name, buy = b, sell = s }
            seen = seen + 1
        end
    end
    return seen
end

local function load_gold()
    local urls = {
        "https://edge-api.pnj.io/ecom-frontend/v1/get-gold-price?zone=00",
        "http://giavang.doji.vn/api/giavang/?api_key=258fbd2a72ce8481089d88c678e9fe4f",
        "https://api.btmc.vn/api/BTMCAPI/getpricebtmc?key=3kd8ub1llcg9t45hnoh8hmn7t5kc2v",
        "https://api.gold-api.com/price/XAU",
        "https://sjc.com.vn/xml/tygiavang.xml",
        "https://vnexpress.net/rss/kinh-doanh.rss",
        "https://tuoitre.vn/rss/kinh-doanh.rss",
        "https://vietnamnet.vn/rss/kinh-doanh.rss",
        "https://news.google.com/rss/search?q=" .. urlencode("giá vàng hôm nay when:2d") .. "&hl=vi&gl=VN&ceid=VN:vi",
    }
    local raws = fetch_many(urls)
    for i = 1, 5 do log("gold raw" .. i .. ": " .. tostring(raws[i] and raws[i]:sub(1, 300)):gsub("\n", " ")) end
    log("gold doji body: " .. tostring(raws[2] and raws[2]:gsub("%s+", " "):sub(1, 3000)))
    local rows = {}
    -- SJC (xml, có thể bị chặn)
    pcall(function()
        local list = {}
        for tag in (raws[5] or ""):gmatch("<item%s([^>]*)>") do
            local a = attrs_of(tag)
            list[#list + 1] = { name = a.type or a.name, buy = a.buy, sell = a.sell }
        end
        add_rows(rows, "SJC", list, 2)
    end)
    -- PNJ (kèm giá SJC niêm yết tại PNJ)
    pcall(function()
        local j = decode(raws[1])
        if j and type(j.data) == "table" then
            local pick, rest = {}, {}
            for _, e in ipairs(j.data) do
                local item = { name = e.tensp or e.name, buy = e.giamua or e.buy, sell = e.giaban or e.sell }
                if e.masp == "SJC" or e.masp == "N24K" or e.masp == "PNJ" then pick[#pick + 1] = item else rest[#rest + 1] = item end
            end
            for _, e in ipairs(rest) do pick[#pick + 1] = e end
            add_rows(rows, "PNJ", pick, 3)
        end
    end)
    -- DOJI
    pcall(function()
        local list = {}
        for tag in (raws[2] or ""):gmatch("<[Rr]ow%s([^>]*)>") do
            local a = attrs_of(tag)
            list[#list + 1] = { name = a.Name or a.Key, buy = a.Buy, sell = a.Sell }
        end
        add_rows(rows, "DOJI", list, 3)
    end)
    -- Bảo Tín Minh Châu
    pcall(function()
        local j = decode(raws[3])
        local data = j and j.DataList and j.DataList.Data
        local list = {}
        if type(data) == "table" then
            for _, e in ipairs(data) do
                local r = tostring(e["@row"] or "")
                list[#list + 1] = { name = e["@n_" .. r], buy = e["@pm_" .. r], sell = e["@pb_" .. r] }
            end
        end
        add_rows(rows, "BTMC", list, 3)
    end)
    -- vàng thế giới
    pcall(function()
        local j = decode(raws[4])
        if j and tonumber(j.price) then
            rows[#rows + 1] = { src = "Thế giới", unit = "USD/ounce", name = "Vàng XAU/USD", buy = tonumber(j.price), usd = true }
        end
    end)
    -- tin giá vàng (có sub-head từ báo điện tử, sau đó là Google News)
    local news, seen = {}, {}
    local function is_gold(it)
        local s = it.title .. " " .. (it.desc or "")
        return s:find("[Vv]àng") or s:find("VÀNG") or s:find("SJC")
    end
    local function push(list)
        for _, it in ipairs(list) do
            if not seen[it.title] then
                seen[it.title] = true
                news[#news + 1] = it
            end
        end
    end
    push(rss_items(raws[6], "VnExpress", 20, is_gold))
    push(rss_items(raws[7], "Tuổi Trẻ", 20, is_gold))
    push(rss_items(raws[8], "VietNamNet", 20, is_gold))
    push(rss_items(raws[9], "", 30))
    log("gold rows " .. #rows .. ", news " .. #news)
    return { rows = rows, news = news }
end

-- ----- âm lịch (thuật toán Hồ Ngọc Đức) -----
local function jdFromDate(dd, mm, yy)
    local a = math.floor((14 - mm) / 12)
    local y = yy + 4800 - a
    local m = mm + 12 * a - 3
    return dd + math.floor((153 * m + 2) / 5) + 365 * y + math.floor(y / 4) - math.floor(y / 100) + math.floor(y / 400) - 32045
end

local function NewMoon(k)
    local T = k / 1236.85
    local T2 = T * T
    local T3 = T2 * T
    local dr = math.pi / 180
    local Jd1 = 2415020.75933 + 29.53058868 * k + 0.0001178 * T2 - 0.000000155 * T3
    Jd1 = Jd1 + 0.00033 * math.sin((166.56 + 132.87 * T - 0.009173 * T2) * dr)
    local M = 359.2242 + 29.10535608 * k - 0.0000333 * T2 - 0.00000347 * T3
    local Mpr = 306.0253 + 385.81691806 * k + 0.0107306 * T2 + 0.00001236 * T3
    local F = 21.2964 + 390.67050646 * k - 0.0016528 * T2 - 0.00000239 * T3
    local C1 = (0.1734 - 0.000393 * T) * math.sin(M * dr) + 0.0021 * math.sin(2 * dr * M)
    C1 = C1 - 0.4068 * math.sin(Mpr * dr) + 0.0161 * math.sin(dr * 2 * Mpr)
    C1 = C1 - 0.0004 * math.sin(dr * 3 * Mpr)
    C1 = C1 + 0.0104 * math.sin(dr * 2 * F) - 0.0051 * math.sin(dr * (M + Mpr))
    C1 = C1 - 0.0074 * math.sin(dr * (M - Mpr)) + 0.0004 * math.sin(dr * (2 * F + M))
    C1 = C1 - 0.0004 * math.sin(dr * (2 * F - M)) - 0.0006 * math.sin(dr * (2 * F + Mpr))
    C1 = C1 + 0.0010 * math.sin(dr * (2 * F - Mpr)) + 0.0005 * math.sin(dr * (2 * Mpr + M))
    local deltat
    if T < -11 then
        deltat = 0.001 + 0.000839 * T + 0.0002261 * T2 - 0.00000845 * T3 - 0.000000081 * T * T3
    else
        deltat = -0.000278 + 0.000265 * T + 0.000262 * T2
    end
    return Jd1 + C1 - deltat
end

local function getNewMoonDay(k, tz)
    return math.floor(NewMoon(k) + 0.5 + tz / 24)
end

local function SunLongitude(jdn)
    local T = (jdn - 2451545.0) / 36525
    local T2 = T * T
    local dr = math.pi / 180
    local M = 357.52910 + 35999.05030 * T - 0.0001559 * T2 - 0.00000048 * T * T2
    local L0 = 280.46645 + 36000.76983 * T + 0.0003032 * T2
    local DL = (1.914600 - 0.004817 * T - 0.000014 * T2) * math.sin(dr * M)
    DL = DL + (0.019993 - 0.000101 * T) * math.sin(dr * 2 * M) + 0.000290 * math.sin(dr * 3 * M)
    local L = (L0 + DL) * dr
    L = L - math.pi * 2 * math.floor(L / (math.pi * 2))
    return L
end

local function getSunLongitude(dayNumber, tz)
    return math.floor(SunLongitude(dayNumber - 0.5 - tz / 24) / math.pi * 6)
end

local function getLunarMonth11(yy, tz)
    local off = jdFromDate(31, 12, yy) - 2415021
    local k = math.floor(off / 29.530588853)
    local nm = getNewMoonDay(k, tz)
    if getSunLongitude(nm, tz) >= 9 then nm = getNewMoonDay(k - 1, tz) end
    return nm
end

local function getLeapMonthOffset(a11, tz)
    local k = math.floor((a11 - 2415021.076998695) / 29.530588853 + 0.5)
    local i = 1
    local arc = getSunLongitude(getNewMoonDay(k + i, tz), tz)
    local last
    repeat
        last = arc
        i = i + 1
        arc = getSunLongitude(getNewMoonDay(k + i, tz), tz)
    until not (arc ~= last and i < 14)
    return i - 1
end

local function solar2lunar(dd, mm, yy)
    local tz = 7
    local dayNumber = jdFromDate(dd, mm, yy)
    local k = math.floor((dayNumber - 2415021.076998695) / 29.530588853)
    local monthStart = getNewMoonDay(k + 1, tz)
    if monthStart > dayNumber then monthStart = getNewMoonDay(k, tz) end
    local a11 = getLunarMonth11(yy, tz)
    local b11 = a11
    local lunarYear
    if a11 >= monthStart then
        lunarYear = yy
        a11 = getLunarMonth11(yy - 1, tz)
    else
        lunarYear = yy + 1
        b11 = getLunarMonth11(yy + 1, tz)
    end
    local lunarDay = dayNumber - monthStart + 1
    local diff = math.floor((monthStart - a11) / 29)
    local lunarLeap = false
    local lunarMonth = diff + 11
    if b11 - a11 > 365 then
        local leapMonthDiff = getLeapMonthOffset(a11, tz)
        if diff >= leapMonthDiff then
            lunarMonth = diff + 10
            if diff == leapMonthDiff then lunarLeap = true end
        end
    end
    if lunarMonth > 12 then lunarMonth = lunarMonth - 12 end
    if lunarMonth >= 11 and diff < 4 then lunarYear = lunarYear - 1 end
    return lunarDay, lunarMonth, lunarYear, lunarLeap
end

local CAN = { "Giáp", "Ất", "Bính", "Đinh", "Mậu", "Kỷ", "Canh", "Tân", "Nhâm", "Quý" }
local CHI = { "Tý", "Sửu", "Dần", "Mão", "Thìn", "Tị", "Ngọ", "Mùi", "Thân", "Dậu", "Tuất", "Hợi" }

local function canchi_year(y) return CAN[(y + 6) % 10 + 1] .. " " .. CHI[(y + 8) % 12 + 1] end
local function canchi_day(dd, mm, yy)
    local jd = jdFromDate(dd, mm, yy)
    return CAN[(jd + 9) % 10 + 1] .. " " .. CHI[(jd + 1) % 12 + 1]
end

local SOLAR_EVENTS = {
    { 1, 1, "Tết Dương lịch" }, { 14, 2, "Valentine" }, { 8, 3, "Quốc tế Phụ nữ" },
    { 30, 4, "Giải phóng miền Nam" }, { 1, 5, "Quốc tế Lao động" }, { 1, 6, "Quốc tế Thiếu nhi" },
    { 2, 9, "Quốc khánh" }, { 20, 10, "Ngày Phụ nữ Việt Nam" }, { 20, 11, "Ngày Nhà giáo Việt Nam" },
    { 24, 12, "Đêm Giáng sinh" }, { 25, 12, "Giáng sinh" },
}
local LUNAR_EVENTS = {
    { 1, 1, "Tết Nguyên đán" }, { 15, 1, "Rằm tháng Giêng" }, { 3, 3, "Tết Hàn thực" },
    { 10, 3, "Giỗ Tổ Hùng Vương" }, { 15, 4, "Lễ Phật đản" }, { 5, 5, "Tết Đoan ngọ" },
    { 15, 7, "Lễ Vu lan" }, { 15, 8, "Tết Trung thu" }, { 23, 12, "Ông Táo chầu trời" },
}

local function upcoming_events(n, horizon)
    local res = {}
    local now = os.time()
    for off = 0, horizon do
        local t = os.date("*t", now + off * 86400)
        local names = {}
        for _, e in ipairs(SOLAR_EVENTS) do
            if e[1] == t.day and e[2] == t.month then names[#names + 1] = e[3] end
        end
        local ld, lm, _, leap = solar2lunar(t.day, t.month, t.year)
        if not leap then
            for _, e in ipairs(LUNAR_EVENTS) do
                if e[1] == ld and e[2] == lm then names[#names + 1] = e[3] end
            end
        end
        for _, nm in ipairs(names) do
            res[#res + 1] = { off = off, day = t.day, month = t.month, name = nm }
            if #res >= n then return res end
        end
    end
    return res
end

local QUOTES = {
    "Có công mài sắt, có ngày nên kim.",
    "Không thầy đố mày làm nên.",
    "Đi một ngày đàng, học một sàng khôn.",
    "Một cây làm chẳng nên non, ba cây chụm lại nên hòn núi cao.",
    "Nước chảy đá mòn.",
    "Kiến tha lâu cũng đầy tổ.",
    "Thất bại là mẹ thành công.",
    "Cẩn tắc vô áy náy.",
    "Gần mực thì đen, gần đèn thì sáng.",
    "Ăn quả nhớ kẻ trồng cây.",
    "Có chí thì nên.",
    "Thua keo này, bày keo khác.",
    "Học ăn, học nói, học gói, học mở.",
    "Lời nói chẳng mất tiền mua, lựa lời mà nói cho vừa lòng nhau.",
    "Buôn có bạn, bán có phường.",
    "Chậm mà chắc.",
    "Đừng bỏ tất cả trứng vào một giỏ.",
    "Có làm thì mới có ăn.",
    "Biết người biết ta, trăm trận trăm thắng.",
    "Làm việc gì cũng phải có đầu có cuối.",
    "Tích tiểu thành đại.",
    "Rút dây động rừng, nghĩ kỹ rồi hãy làm.",
    "Điều gì không làm được hôm nay, chớ hẹn đến ngày mai.",
    "Mưa dầm thấm lâu.",
    "Dục tốc bất đạt.",
    "Hãy làm điều nhỏ bằng tình yêu lớn.",
    "Đường dài mới biết ngựa hay.",
    "Tiên học lễ, hậu học văn.",
    "Thương người như thể thương thân.",
    "Uống nước nhớ nguồn.",
}

local HIST = {
    { 1, 1, 1804, "Haiti tuyên bố độc lập, trở thành nước cộng hòa da đen đầu tiên trên thế giới." },
    { 3, 2, 1930, "Đảng Cộng sản Việt Nam được thành lập tại Hương Cảng (Hồng Kông)." },
    { 6, 2, 2012, "Chỉ số VN30 chính thức được tính và công bố trên sàn HOSE." },
    { 11, 2, 1990, "Nelson Mandela được trả tự do sau 27 năm bị giam cầm." },
    { 14, 3, 1879, "Albert Einstein chào đời tại Ulm, nước Đức." },
    { 12, 3, 2007, "VN-Index chạm đỉnh lịch sử khi đó, khoảng 1.170 điểm." },
    { 9, 3, 1945, "Nhật đảo chính Pháp ở Đông Dương." },
    { 26, 3, 1931, "Đoàn Thanh niên Cộng sản Hồ Chí Minh được thành lập." },
    { 1, 4, 1976, "Apple được thành lập bởi Steve Jobs, Steve Wozniak và Ronald Wayne." },
    { 4, 4, 1975, "Microsoft được Bill Gates và Paul Allen thành lập." },
    { 12, 4, 1961, "Yuri Gagarin trở thành người đầu tiên bay vào vũ trụ." },
    { 15, 4, 1912, "Tàu Titanic chìm ở Bắc Đại Tây Dương sau khi va vào tảng băng." },
    { 22, 4, 1970, "Ngày Trái Đất được tổ chức lần đầu tiên." },
    { 30, 4, 1975, "Giải phóng miền Nam, thống nhất đất nước." },
    { 7, 5, 1954, "Chiến thắng Điện Biên Phủ kết thúc cuộc kháng chiến chống Pháp." },
    { 19, 5, 1890, "Chủ tịch Hồ Chí Minh sinh ra tại làng Hoàng Trù, Nghệ An." },
    { 5, 5, 1818, "Karl Marx chào đời tại Trier, nước Đức." },
    { 5, 6, 1911, "Nguyễn Tất Thành rời bến Nhà Rồng ra đi tìm đường cứu nước." },
    { 24, 6, 2009, "Thị trường UPCoM chính thức đi vào hoạt động." },
    { 28, 6, 1919, "Hòa ước Versailles được ký, chính thức kết thúc Thế chiến thứ nhất." },
    { 4, 7, 1776, "Hoa Kỳ thông qua Tuyên ngôn Độc lập." },
    { 14, 7, 1789, "Quần chúng Paris chiếm ngục Bastille, mở đầu Cách mạng Pháp." },
    { 20, 7, 1954, "Hiệp định Genève được ký kết, chấm dứt chiến tranh ở Đông Dương." },
    { 20, 7, 1969, "Apollo 11 hạ cánh; Neil Armstrong là người đầu tiên đặt chân lên Mặt Trăng." },
    { 28, 7, 2000, "Phiên giao dịch đầu tiên của Trung tâm Giao dịch Chứng khoán TP.HCM; VN-Index xuất phát từ 100 điểm." },
    { 28, 7, 1914, "Áo-Hung tuyên chiến với Serbia, mở màn Thế chiến thứ nhất." },
    { 6, 8, 1945, "Mỹ ném bom nguyên tử xuống Hiroshima." },
    { 9, 8, 1945, "Mỹ ném bom nguyên tử xuống Nagasaki." },
    { 15, 8, 1945, "Nhật Bản tuyên bố đầu hàng Đồng minh." },
    { 19, 8, 1945, "Cách mạng Tháng Tám thành công ở Hà Nội." },
    { 1, 9, 1939, "Đức tấn công Ba Lan, Thế chiến thứ hai bùng nổ." },
    { 2, 9, 1945, "Chủ tịch Hồ Chí Minh đọc Tuyên ngôn Độc lập tại Quảng trường Ba Đình." },
    { 2, 9, 1969, "Chủ tịch Hồ Chí Minh từ trần." },
    { 11, 9, 2001, "Vụ tấn công khủng bố 11/9 tại Hoa Kỳ." },
    { 23, 9, 1945, "Nhân dân Nam Bộ bắt đầu cuộc kháng chiến chống thực dân Pháp quay lại." },
    { 2, 10, 1869, "Mahatma Gandhi chào đời tại Ấn Độ." },
    { 4, 10, 1957, "Liên Xô phóng Sputnik 1, vệ tinh nhân tạo đầu tiên của loài người." },
    { 10, 10, 1954, "Quân đội nhân dân Việt Nam tiến vào tiếp quản Thủ đô Hà Nội." },
    { 20, 10, 1930, "Hội Liên hiệp Phụ nữ Việt Nam được thành lập." },
    { 24, 10, 1945, "Liên Hợp Quốc chính thức ra đời." },
    { 29, 10, 1969, "Tin nhắn đầu tiên được gửi qua ARPANET, tiền thân của Internet." },
    { 9, 11, 1989, "Bức tường Berlin sụp đổ." },
    { 11, 11, 1918, "Đình chiến chấm dứt giao tranh Thế chiến thứ nhất." },
    { 12, 11, 1866, "Tôn Trung Sơn, lãnh tụ Cách mạng Tân Hợi của Trung Quốc, chào đời." },
    { 12, 11, 1990, "Tim Berners-Lee đề xuất dự án World Wide Web." },
    { 20, 11, 1982, "Ngày Nhà giáo Việt Nam 20/11 được tổ chức lần đầu tiên." },
    { 22, 11, 1963, "Tổng thống Hoa Kỳ John F. Kennedy bị ám sát ở Dallas." },
    { 7, 12, 1941, "Nhật tấn công Trân Châu Cảng, Mỹ tham chiến Thế chiến thứ hai." },
    { 10, 12, 1948, "Đại hội đồng Liên Hợp Quốc thông qua Tuyên ngôn Quốc tế Nhân quyền." },
    { 17, 12, 1903, "Anh em nhà Wright thực hiện chuyến bay có động cơ đầu tiên." },
    { 18, 12, 1972, "Mở đầu chiến dịch 12 ngày đêm 'Hà Nội – Điện Biên Phủ trên không'." },
    { 19, 12, 1946, "Chủ tịch Hồ Chí Minh ra Lời kêu gọi toàn quốc kháng chiến." },
    { 20, 12, 1960, "Mặt trận Dân tộc Giải phóng miền Nam Việt Nam được thành lập." },
    { 22, 12, 1944, "Đội Việt Nam Tuyên truyền Giải phóng quân – tiền thân Quân đội nhân dân Việt Nam – ra đời." },
    { 25, 12, 1991, "Mikhail Gorbachev từ chức, Liên Xô sắp chấm dứt tồn tại." },
}

-- trả về nhãn và danh sách sự kiện cho hôm nay (hoặc ngày gần nhất sắp tới)
local function history_for_today()
    local now = os.time()
    for off = 0, 120 do
        local t = os.date("*t", now + off * 86400)
        local list = {}
        for _, e in ipairs(HIST) do
            if e[1] == t.day and e[2] == t.month then list[#list + 1] = { year = e[3], text = e[4] } end
        end
        if #list > 0 then
            if off == 0 then return "HÔM NAY TRONG LỊCH SỬ", list end
            return string.format("LỊCH SỬ · %02d/%02d (CÒN %d NGÀY)", t.day, t.month, off), list
        end
    end
    return "HÔM NAY TRONG LỊCH SỬ", {}
end

local WORDS = {
    { "resilient", "/rɪˈzɪliənt/", "adj", "kiên cường, có khả năng phục hồi", "The market proved resilient after the sell-off.", "Thị trường tỏ ra kiên cường sau đợt bán tháo." },
    { "volatile", "/ˈvɒlətaɪl/", "adj", "biến động mạnh, dễ thay đổi", "Oil prices remain highly volatile.", "Giá dầu vẫn biến động rất mạnh." },
    { "leverage", "/ˈlevərɪdʒ/", "n, v", "đòn bẩy; tận dụng", "They used leverage to expand quickly.", "Họ dùng đòn bẩy để mở rộng nhanh." },
    { "diversify", "/daɪˈvɜːsɪfaɪ/", "v", "đa dạng hoá", "It is wise to diversify your portfolio.", "Nên đa dạng hoá danh mục đầu tư." },
    { "pragmatic", "/præɡˈmætɪk/", "adj", "thực dụng, thực tế", "She takes a pragmatic approach to problems.", "Cô ấy tiếp cận vấn đề một cách thực tế." },
    { "meticulous", "/məˈtɪkjələs/", "adj", "tỉ mỉ, cẩn thận", "He is meticulous about every detail.", "Anh ấy cực kỳ tỉ mỉ từng chi tiết." },
    { "mitigate", "/ˈmɪtɪɡeɪt/", "v", "giảm nhẹ, làm dịu bớt", "We must mitigate the risks early.", "Chúng ta phải giảm thiểu rủi ro từ sớm." },
    { "inevitable", "/ɪnˈevɪtəbl/", "adj", "không thể tránh khỏi", "Change is inevitable in any industry.", "Thay đổi là điều không tránh khỏi ở mọi ngành." },
    { "scrutiny", "/ˈskruːtəni/", "n", "sự xem xét kỹ lưỡng", "The deal is under close scrutiny.", "Thương vụ đang bị xem xét kỹ lưỡng." },
    { "sustainable", "/səˈsteɪnəbl/", "adj", "bền vững", "We need a sustainable growth model.", "Chúng ta cần mô hình tăng trưởng bền vững." },
    { "ambiguous", "/æmˈbɪɡjuəs/", "adj", "mơ hồ, nhiều nghĩa", "The contract wording is ambiguous.", "Câu chữ trong hợp đồng khá mơ hồ." },
    { "thrive", "/θraɪv/", "v", "phát triển mạnh, thịnh vượng", "Small businesses thrive in this area.", "Doanh nghiệp nhỏ phát đạt ở khu vực này." },
    { "obsolete", "/ˌɒbsəˈliːt/", "adj", "lỗi thời", "Paper maps are almost obsolete now.", "Bản đồ giấy gần như lỗi thời rồi." },
    { "tangible", "/ˈtændʒəbl/", "adj", "hữu hình, rõ ràng", "We need tangible results, not promises.", "Chúng ta cần kết quả rõ ràng, không phải lời hứa." },
    { "feasible", "/ˈfiːzəbl/", "adj", "khả thi", "Is the plan financially feasible?", "Kế hoạch có khả thi về tài chính không?" },
    { "substantial", "/səbˈstænʃl/", "adj", "đáng kể, lớn", "There was a substantial increase in sales.", "Doanh số tăng đáng kể." },
    { "reluctant", "/rɪˈlʌktənt/", "adj", "miễn cưỡng, do dự", "He was reluctant to sell his shares.", "Anh ấy do dự không muốn bán cổ phiếu." },
    { "consensus", "/kənˈsensəs/", "n", "sự đồng thuận", "The board reached a consensus.", "Hội đồng quản trị đã đạt được đồng thuận." },
    { "prudent", "/ˈpruːdnt/", "adj", "thận trọng, khôn ngoan", "A prudent investor keeps some cash.", "Nhà đầu tư thận trọng luôn giữ lại một ít tiền mặt." },
    { "bottleneck", "/ˈbɒtlnek/", "n", "điểm nghẽn", "Logistics is the main bottleneck.", "Logistics là điểm nghẽn chính." },
    { "outperform", "/ˌaʊtpəˈfɔːm/", "v", "vượt trội hơn", "The fund outperformed the index.", "Quỹ này vượt trội hơn chỉ số." },
    { "setback", "/ˈsetbæk/", "n", "trở ngại, bước lùi", "The delay was a minor setback.", "Việc chậm trễ chỉ là trở ngại nhỏ." },
    { "stakeholder", "/ˈsteɪkhəʊldə/", "n", "bên liên quan", "We must inform every stakeholder.", "Phải thông báo cho mọi bên liên quan." },
    { "accountable", "/əˈkaʊntəbl/", "adj", "có trách nhiệm giải trình", "Managers are accountable for results.", "Quản lý chịu trách nhiệm về kết quả." },
    { "streamline", "/ˈstriːmlaɪn/", "v", "tinh giản, làm cho hiệu quả hơn", "They streamlined the approval process.", "Họ tinh giản quy trình phê duyệt." },
    { "ubiquitous", "/juːˈbɪkwɪtəs/", "adj", "có mặt khắp nơi", "Smartphones are ubiquitous today.", "Điện thoại thông minh có mặt ở khắp nơi." },
    { "nuance", "/ˈnjuːɑːns/", "n", "sắc thái, điểm tinh tế", "Translation loses some nuance.", "Bản dịch làm mất đi một số sắc thái." },
    { "endeavor", "/ɪnˈdevə/", "n, v", "nỗ lực; cố gắng", "Learning a language is a long endeavor.", "Học một ngôn ngữ là nỗ lực lâu dài." },
    { "curb", "/kɜːb/", "v", "kiềm chế, hạn chế", "The bank raised rates to curb inflation.", "Ngân hàng tăng lãi suất để kiềm chế lạm phát." },
    { "surge", "/sɜːdʒ/", "n, v", "đợt tăng vọt; tăng mạnh", "Demand surged after the announcement.", "Nhu cầu tăng vọt sau thông báo." },
    { "plummet", "/ˈplʌmɪt/", "v", "lao dốc, rớt mạnh", "Share prices plummeted overnight.", "Giá cổ phiếu lao dốc chỉ sau một đêm." },
    { "hinder", "/ˈhɪndə/", "v", "cản trở", "Red tape can hinder progress.", "Thủ tục rườm rà có thể cản trở tiến độ." },
    { "perseverance", "/ˌpɜːsəˈvɪərəns/", "n", "sự kiên trì", "Success takes talent and perseverance.", "Thành công cần cả tài năng lẫn sự kiên trì." },
    { "candid", "/ˈkændɪd/", "adj", "thẳng thắn, trung thực", "Thanks for your candid feedback.", "Cảm ơn góp ý thẳng thắn của bạn." },
    { "tedious", "/ˈtiːdiəs/", "adj", "tẻ nhạt, nhàm chán", "Data entry can be tedious.", "Nhập dữ liệu có thể khá nhàm chán." },
    { "versatile", "/ˈvɜːsətaɪl/", "adj", "đa năng, linh hoạt", "He is a versatile engineer.", "Anh ấy là kỹ sư đa năng." },
    { "undermine", "/ˌʌndəˈmaɪn/", "v", "làm suy yếu", "Rumors can undermine confidence.", "Tin đồn có thể làm suy yếu niềm tin." },
    { "foster", "/ˈfɒstə/", "v", "nuôi dưỡng, thúc đẩy", "Good leaders foster teamwork.", "Lãnh đạo giỏi thúc đẩy tinh thần đồng đội." },
    { "lucrative", "/ˈluːkrətɪv/", "adj", "sinh lợi cao", "It was a lucrative business deal.", "Đó là một thương vụ sinh lời lớn." },
    { "wary", "/ˈweəri/", "adj", "dè dặt, cảnh giác", "Investors are wary of new risks.", "Nhà đầu tư dè dặt trước các rủi ro mới." },
    { "benchmark", "/ˈbentʃmɑːk/", "n", "mốc tham chiếu, chuẩn so sánh", "The VN-Index is a market benchmark.", "VN-Index là chuẩn tham chiếu của thị trường." },
    { "stagnant", "/ˈstæɡnənt/", "adj", "trì trệ, đình trệ", "Wages have remained stagnant.", "Tiền lương vẫn trì trệ." },
    { "cautious", "/ˈkɔːʃəs/", "adj", "thận trọng", "Be cautious with unknown links.", "Hãy thận trọng với các đường link lạ." },
    { "elaborate", "/ɪˈlæbərət/", "adj, v", "công phu; nói rõ thêm", "Could you elaborate on that point?", "Bạn nói rõ thêm điểm đó được không?" },
}

local WORDFILE = "/mnt/us/vn_dash/word_idx.txt"

local function cut(s, maxchars)
    local n = 0
    local out = {}
    for ch in s:gmatch("[%z\1-\127\194-\244][\128-\191]*") do
        n = n + 1
        if n > maxchars then
            out[#out + 1] = "…"
            break
        end
        out[#out + 1] = ch
    end
    return table.concat(out)
end

local function cut_sent(s, n)
    if #s <= n then return s end
    local head = s:sub(1, n)
    local last = 0
    local pos = 1
    while true do
        local a = head:find("%. ", pos)
        if not a then break end
        last = a
        pos = a + 1
    end
    if last > n * 0.45 then return head:sub(1, last) end
    return cut(s, n)
end


local function resolve_google(link)
    local id = link:match("/articles/([%w_%-]+)")
    if not id then return link end
    local cmd = "echo '" .. id .. "' | tr '_-' '/+' | base64 -d 2>/dev/null | tr -c '[:print:]' '\\n' | grep -o 'https\\?://[^ ]*' | head -1"
    local p = io.popen(cmd, "r")
    if not p then return link end
    local s = p:read("*a") or ""
    p:close()
    s = s:gsub("%s+", "")
    if s:find("^https?://") then
        log("google resolved: " .. s:sub(1, 80))
        return s
    end
    return link
end

local function meta_desc(html)
    for tag in html:gmatch("<[Mm]eta%s[^>]-/?>") do
        if tag:find('og:description', 1, true) or tag:find('name="description"', 1, true) or tag:find("name='description'", 1, true) then
            local c = tag:match('content="(.-)"') or tag:match("content='(.-)'")
            if c and c ~= "" then return c end
        end
    end
    return nil
end

local function fetch_desc(link)
    if not link or link == "" then return "" end
    local url = link
    if url:find("news.google.com", 1, true) then url = resolve_google(url) end
    local html = fetch(url, 12)
    if not html then return "" end
    local d = meta_desc(html)
    if not d then
        log("no desc: " .. url:sub(1, 70))
        return ""
    end
    d = strip_html(d)
    if d:find("Google News", 1, true) or d:find("Comprehensive", 1, true) then return "" end
    log("desc ok (" .. #d .. "): " .. url:sub(1, 70))
    return cut(d, 420)
end

local function is_trading_time()
    local t = os.date("*t")
    local mins = t.hour * 60 + t.min
    return t.wday >= 2 and t.wday <= 6 and mins >= 540 and mins < 900
end

-- ===== vẽ =====
local function face(px)
    local s = math.floor(px * 100 / Screen:scaleBySize(100) + 0.5)
    if s < 6 then s = 6 end
    return Font:getFace("cfont", s)
end

-- vẽ chữ; opts: bold, color, right (x là mép phải), center (x là tâm), max_width
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

local function tri(bb, cx, cy, s, up, color)
    local b = math.floor(s * 1.15)
    for i = 0, s - 1 do
        local wi
        if up then wi = math.max(2, math.floor(b * (i + 1) / s)) else wi = math.max(2, math.floor(b * (s - i) / s)) end
        bb:paintRect(cx - math.floor(wi / 2), cy - math.floor(s / 2) + i, wi, 1, color)
    end
end

local function pill(bb, x, y, w, h, kind, px)
    local label = (kind == "up") and "TĂNG" or ((kind == "down") and "GIẢM" or "ĐỨNG")
    local r = math.floor(h / 2)
    local fg
    if kind == "up" then
        bb:paintRoundedRect(x, y, w, h, BLACK, r)
        fg = WHITE
    elseif kind == "down" then
        bb:paintRoundedRect(x, y, w, h, BLACK, r)
        local bwd = math.max(3, math.floor(h / 14))
        bb:paintRoundedRect(x + bwd, y + bwd, w - 2 * bwd, h - 2 * bwd, WHITE, r - bwd)
        fg = BLACK
    else
        bb:paintBorder(x, y, w, h, 2, BLACK, r)
        fg = BLACK
    end
    local tw = TextWidget:new{ text = label, face = face(px), bold = true, fgcolor = fg, padding = 0 }
    local lw = tw:getWidth()
    local th = tw:getSize().h
    local ts = math.floor(px * 0.62)
    local gap = math.floor(px * 0.4)
    local total = ts + gap + lw
    local sx = x + math.floor((w - total) / 2)
    local cy = y + math.floor(h / 2)
    if kind == "up" then
        tri(bb, sx + math.floor(ts / 2), cy, ts, true, fg)
    elseif kind == "down" then
        tri(bb, sx + math.floor(ts / 2), cy, ts, false, fg)
    else
        bb:paintRect(sx, cy - math.floor(ts / 2), ts, ts, fg)
    end
    tw:paintTo(bb, sx + ts + gap, cy - math.floor(th / 2))
    tw:free()
end

local function disc(bb, cx, cy, r, color)
    r = math.max(1, math.floor(r))
    bb:paintRoundedRect(math.floor(cx - r), math.floor(cy - r), 2 * r, 2 * r, color, r)
end

local function cloud(bb, cx, cy, s, color)
    disc(bb, cx - 0.17 * s, cy + 0.04 * s, 0.17 * s, color)
    disc(bb, cx + 0.03 * s, cy - 0.08 * s, 0.23 * s, color)
    disc(bb, cx + 0.23 * s, cy + 0.05 * s, 0.16 * s, color)
    bb:paintRoundedRect(math.floor(cx - 0.34 * s), math.floor(cy + 0.02 * s), math.floor(0.72 * s), math.floor(0.2 * s), color, math.floor(0.1 * s))
end

local function sun(bb, cx, cy, s)
    disc(bb, cx, cy, 0.2 * s, BLACK)
    for k = 0, 7 do
        local ang = k * math.pi / 4
        for _, dist in ipairs({ 0.33, 0.42 }) do
            disc(bb, cx + math.cos(ang) * dist * s, cy + math.sin(ang) * dist * s, math.max(2, 0.03 * s), BLACK)
        end
    end
end

local function wx_icon(bb, cx, cy, s, kind)
    local dark = Blitbuffer.COLOR_GRAY_4
    if kind == "sun" then
        sun(bb, cx, cy, s)
    elseif kind == "partly" then
        sun(bb, cx - 0.18 * s, cy - 0.16 * s, 0.7 * s)
        cloud(bb, cx + 0.08 * s, cy + 0.12 * s, 0.8 * s, dark)
    elseif kind == "cloud" then
        cloud(bb, cx, cy, s, dark)
    elseif kind == "fog" then
        for i = -1, 1 do
            bb:paintRoundedRect(math.floor(cx - 0.35 * s), math.floor(cy + i * 0.2 * s), math.floor(0.7 * s), math.max(3, math.floor(0.08 * s)), dark, 2)
        end
    elseif kind == "snow" then
        cloud(bb, cx, cy - 0.12 * s, 0.9 * s, dark)
        for i = -1, 1 do
            disc(bb, cx + i * 0.22 * s, cy + 0.3 * s, math.max(2, 0.04 * s), BLACK)
        end
    else -- rain / storm
        cloud(bb, cx, cy - 0.12 * s, 0.9 * s, dark)
        for i = -1, 1 do
            bb:paintRect(math.floor(cx + i * 0.2 * s), math.floor(cy + 0.22 * s), math.max(3, math.floor(0.04 * s)), math.floor(0.16 * s), BLACK)
        end
        if kind == "storm" then
            tri(bb, cx + 0.3 * s, cy + 0.3 * s, math.floor(0.14 * s), false, BLACK)
        end
    end
end

local function kind_of(change)
    if change > 0 then return "up" elseif change < 0 then return "down" end
    return "flat"
end

local TABS = {
    { "stocks", "CHỨNG KHOÁN" },
    { "gold", "VÀNG" },
    { "news", "TIN TỨC" },
    { "weather", "THỜI TIẾT" },
    { "calendar", "LỊCH" },
}

local WEEKDAYS = { [0] = "Chủ nhật", "Thứ Hai", "Thứ Ba", "Thứ Tư", "Thứ Năm", "Thứ Sáu", "Thứ Bảy" }

local function badge(bb, x, y, w, h, kind, text, px)
    local r = math.floor(h / 2)
    local fg
    if kind == "up" then
        bb:paintRoundedRect(x, y, w, h, BLACK, r)
        fg = WHITE
    elseif kind == "down" then
        bb:paintRoundedRect(x, y, w, h, BLACK, r)
        local b = math.max(3, math.floor(h / 12))
        bb:paintRoundedRect(x + b, y + b, w - 2 * b, h - 2 * b, WHITE, r - b)
        fg = BLACK
    else
        bb:paintBorder(x, y, w, h, 2, BLACK, r)
        fg = BLACK
    end
    local tw = TextWidget:new{ text = text, face = face(px), bold = true, fgcolor = fg, padding = 0 }
    local lw = tw:getWidth()
    local th = tw:getSize().h
    local ts = math.floor(px * 0.55)
    local gap = math.floor(px * 0.35)
    local total = ts + gap + lw
    local sx = x + math.floor((w - total) / 2)
    local cy = y + math.floor(h / 2)
    if kind == "up" then
        tri(bb, sx + math.floor(ts / 2), cy, ts, true, fg)
    elseif kind == "down" then
        tri(bb, sx + math.floor(ts / 2), cy, ts, false, fg)
    else
        bb:paintRect(sx, cy - math.floor(ts / 2), ts, ts, fg)
    end
    tw:paintTo(bb, sx + ts + gap, cy - math.floor(th / 2))
    tw:free()
end

-- danh sách tiêu đề tin trong một khung, bắt đầu từ mục `start`; trả về số mục đã vẽ
-- hits/onpick: ghi vùng chạm để mở tóm tắt khi bấm vào tin
local function headlines(bb, items, bx, by, bw, bh, cols, fs, start, hits, onpick)
    local pad = 36
    local colgap = 40
    local colw = math.floor((bw - 2 * pad - (cols - 1) * colgap) / cols)
    local col = 0
    local cx = bx + pad
    local cy = by + 28
    local limit = by + bh - 24
    local drawn = 0
    for idx = (start or 1), #items do
        local n = items[idx]
        local tb = TextBoxWidget:new{ text = n.title, face = face(fs), width = colw, fgcolor = BLACK, bold = true }
        local th = tb:getSize().h
        if cy + th + 56 > limit then
            tb:free()
            col = col + 1
            if col >= cols then break end
            cx = bx + pad + col * (colw + colgap)
            cy = by + 28
            tb = TextBoxWidget:new{ text = n.title, face = face(fs), width = colw, fgcolor = BLACK, bold = true }
            th = tb:getSize().h
        end
        local item_top = cy
        tb:paintTo(bb, cx, cy)
        tb:free()
        cy = cy + th + 6
        local meta = n.source or ""
        if n.when and n.when ~= "" then meta = (meta ~= "" and (meta .. "  ·  ") or "") .. n.when end
        txt(bb, meta, cx, cy, 22, { color = Blitbuffer.COLOR_GRAY_5 })
        cy = cy + 34
        bb:paintRect(cx, cy, colw, 1, Blitbuffer.COLOR_GRAY_B)
        if hits and onpick then
            local item = n
            hits[#hits + 1] = { x = cx, y = item_top - 6, w = colw, h = cy - item_top + 18, fn = function() onpick(item) end }
        end
        cy = cy + 20
        drawn = drawn + 1
    end
    return drawn
end

local VNDash = InputContainer:extend{
    name = "vn_dash",
    covers_fullscreen = true,
    mode = "overview",
    tab = "stocks",
    refresh_count = 0,
}

function VNDash:init()
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events = {
        Tap = { GestureRange:new{ ges = "tap", range = self.dimen } },
    }
    self.key_events = {
        CloseDash = { { "Back" } },
    }
    self.hits = {}
    self.indices = {}
    self.news = {}
    self.news_cat = 1
    self.weather = nil
    self.watch = nil
    self.top = nil
    self.gold = nil
    self.cal_cache = {}
    self.nav = {}
    self.sec_page = 1
    self.sec_dpage = 1
    self.wmode = "overview"
    self.detail = nil
end

function VNDash:onCloseDash()
    self:close()
    return true
end

function VNDash:onSetRotationMode(mode)
    if mode ~= nil then
        if mode ~= Screen:getRotationMode() then Screen:setRotationMode(mode) end
        self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
        self.ges_events.Tap = { GestureRange:new{ ges = "tap", range = self.dimen } }
        UIManager:setDirty("all", "full")
        return true
    end
end

function VNDash:onTap(_, ges)
    local p = ges and ges.pos
    if not p then return true end
    for _, hb in ipairs(self.hits) do
        if p.x >= hb.x and p.x < hb.x + hb.w and p.y >= hb.y and p.y < hb.y + hb.h then
            hb.fn()
            return true
        end
    end
    return true
end

-- ----- điều khiển -----
function VNDash:close()
    if self.tick then UIManager:unschedule(self.tick) end
    os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver 0 >/dev/null 2>&1")
    if self.old_rotation ~= nil and self.old_rotation ~= Screen:getRotationMode() then
        Screen:setRotationMode(self.old_rotation)
    end
    UIManager:close(self)
    UIManager:setDirty("all", "full")
end

function VNDash:dataKey()
    if self.tab == "stocks" then
        if self.mode == "overview" or self.mode == "index" then return "indices" end
        if self.mode == "watch" then return "watch" end
        if self.mode == "top" or self.mode == "sector" or self.mode == "heat" then return "top" end
        return nil
    end
    return self.tab
end

function VNDash:hasData(key)
    if key == "indices" then return #self.indices > 0 end
    if key == "watch" then return self.watch ~= nil end
    if key == "top" then return self.top ~= nil end
    if key == "gold" then return self.gold ~= nil end
    if key == "news" then return self.news[self.news_cat] ~= nil end
    if key == "weather" then return self.weather ~= nil end
    return true
end

function VNDash:schedule()
    if self.tick then UIManager:unschedule(self.tick) end
    self.tick = function() self:refresh() end
    local s = is_trading_time() and cfg.interval_trading or cfg.interval_idle
    if self.tab == "weather" or self.tab == "gold" then s = math.max(s, 900) end
    if self.tab == "calendar" then s = 60 end
    UIManager:scheduleIn(s, self.tick)
end

-- chuyển trang (tab hoặc trang con) và tải dữ liệu nếu chưa có
function VNDash:go(tab, mode)
    self.back = nil
    self.tab = tab
    if mode then self.mode = mode end
    UIManager:setDirty(self, "full")
    local key = self:dataKey()
    if key and not self:hasData(key) then
        self:refresh(true)
    else
        self:schedule()
    end
end

function VNDash:refresh(manual)
    local key = self:dataKey()
    if key == nil then
        self:schedule()
        return
    end
    local function finish()
        self.busy = false
        self.refresh_count = self.refresh_count + 1
        local m = (self.refresh_count % 8 == 0 or manual) and "full" or "ui"
        if self:dataKey() == key then UIManager:setDirty(self, m) end
        local Event = require("ui/event")
        UIManager:broadcastEvent(Event:new("InputEvent"))
        self:schedule()
    end
    -- lịch: không cần mạng, chỉ vẽ lại
    if key == "calendar" then
        finish()
        return
    end
    self.busy = true
    local NetworkMgr = require("ui/network/manager")
    NetworkMgr:runWhenOnline(function()
        local ok, err = pcall(function()
            if key == "indices" then
                local urls = {}
                for i, c in ipairs(cfg.cards) do
                    if INDEX_MAP[c] then
                        urls[i] = API .. "/exchange-index/" .. INDEX_MAP[c][1] .. "?hasHistory=true"
                    else
                        urls[i] = API .. "/stock/" .. c
                    end
                end
                local raws = fetch_many(urls)
                local out = {}
                for i, c in ipairs(cfg.cards) do
                    local m = INDEX_MAP[c]
                    if m then
                        out[i] = { id = m[1], name = m[2], foreign = m[3], data = parse_index(decode(raws[i])) }
                    else
                        out[i] = stock_item(c, raws[i])
                    end
                end
                self.indices = out
            elseif key == "watch" then
                self.watch = load_watch()
            elseif key == "top" then
                self.top = load_top()
            elseif key == "gold" then
                self.gold = load_gold()
                if manual then self.nav.gold = nil end
            elseif key == "news" then
                self.news[self.news_cat] = load_category(cfg.news[self.news_cat])
                if manual then self.nav["news" .. self.news_cat] = nil end
            elseif key == "weather" then
                self.weather = load_weather()
            end
            self.updated = os.date("%H:%M %d/%m/%Y")
        end)
        if not ok then log("refresh error (" .. tostring(key) .. "): " .. tostring(err)) end
        finish()
    end)
end

function VNDash:openEdit(kind)
    local isw = (kind == "watch")
    local cur = table.concat(isw and cfg.watchlist or cfg.cards, " ")
    local dlg
    dlg = InputDialog:new{
        title = isw and "Sửa danh mục (cách nhau bằng dấu cách, tối đa 12 mã)" or "Sửa 4 thẻ: chỉ số (VNINDEX VN30 HNX UPCOM) hoặc mã cổ phiếu (VPS FPT…)",
        input = cur,
        input_hint = isw and "VPS FPT HPG VCB…" or "VNINDEX VN30 VPS FPT",
        buttons = {
            {
                { text = "Huỷ", id = "close", callback = function() UIManager:close(dlg) end },
                { text = "Lưu", is_enter_default = true, callback = function()
                    local s = dlg:getInputText() or ""
                    UIManager:close(dlg)
                    local t = words_of(s, isw and 12 or 4)
                    if #t > 0 then
                        if isw then
                            cfg.watchlist = t
                            self.watch = nil
                        else
                            cfg.cards = t
                            self.indices = {}
                        end
                        save_user()
                        UIManager:setDirty(self, "full")
                        self:refresh(true)
                    else
                        UIManager:setDirty(self, "full")
                    end
                end },
            },
        },
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

function VNDash:drawIndexDetail(bb, W, H)
    local mx = 36
    local top, bottom = 206, H - 30 - 84 - 22 - 20
    local it = self.indices[self.index_open or 1]
    if not it or not it.data then
        txt(bb, "Không có dữ liệu chỉ số này", math.floor(W / 2), math.floor((top + bottom) / 2) - 24, 38, { center = true, bold = true })
        return
    end
    local gap = 24
    local lw = math.floor((W - 2 * mx - gap) * 0.6)
    self:drawCard(bb, mx, top, lw, bottom - top, it)
    local d = it.data
    local rx, rw = mx + lw + gap, W - 2 * mx - lw - gap
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    bb:paintBorder(rx, top, rw, bottom - top, 3, BLACK, 26)
    txt(bb, "THÔNG TIN " .. string.upper(it.name), rx + 30, top + 20, 30, { bold = true, max_width = rw - 60 })
    bb:paintRect(rx + 30, top + 68, rw - 60, 3, BLACK)
    local hi, lo
    for _, v in ipairs(d.hist or {}) do
        if not hi or v > hi then hi = v end
        if not lo or v < lo then lo = v end
    end
    local lines = {
        { "Điểm hiện tại", fmt(d.value, 2) },
        { "Tham chiếu", fmt(d.prev, 2) },
        { "Thay đổi", sfmt(d.change, 2) .. "  (" .. sfmt(d.pct, 2) .. "%)" },
        { "Cao nhất phiên", hi and fmt(hi, 2) or "—" },
        { "Thấp nhất phiên", lo and fmt(lo, 2) or "—" },
        { "Mã tăng", tostring(d.adv) },
        { "Mã giảm", tostring(d.dec) },
        { "Mã đứng giá", tostring(d.unch) },
        { "GTGD", fmt(d.val, 0) .. " tỷ" },
    }
    if d.fbuy and d.fsell then
        lines[#lines + 1] = { "NN ròng (KL)", sfmt((d.fbuy - d.fsell) / 1e6, 2) .. " tr cp" }
    end
    local ry = top + 90
    local rowh = math.min(70, math.floor((bottom - 20 - ry) / #lines))
    for _, l in ipairs(lines) do
        txt(bb, l[1], rx + 30, ry + 8, 24, { color = GRAY5 })
        txt(bb, l[2], rx + rw - 30, ry + 2, 32, { right = true, bold = true })
        ry = ry + rowh
        bb:paintRect(rx + 30, ry - 6, rw - 60, 1, Blitbuffer.COLOR_GRAY_B)
    end
end

local BUILD = "2026-11-12 b2"
local UPDATE_URL = "https://raw.githubusercontent.com/Brodekk/bang-dien-toi-thuong/main/main.lua"

local function self_update()
    local src = debug.getinfo(1, "S").source or ""
    local dir = src:match("^@(.*)/main%.lua$")
    if not dir then return false, "Không xác định được thư mục plugin." end
    local tmp = "/mnt/us/vn_dash/update_main.lua"
    os.remove(tmp)
    os.execute('curl -sS -m 40 --connect-timeout 10 -L -A "Mozilla/5.0" -o "' .. tmp .. '" "' .. UPDATE_URL .. "?t=" .. os.time() .. '" 2>/dev/null')
    local f = io.open(tmp, "rb")
    if not f then return false, "Tải thất bại (kiểm tra Wi-Fi)." end
    local body = f:read("*a")
    f:close()
    if #body < 50000 or not body:find("return VNMarket", 1, true) then
        return false, "File tải về không hợp lệ, giữ nguyên bản đang chạy."
    end
    local fn, err = loadfile(tmp)
    if not fn then return false, "File tải về lỗi cú pháp, giữ nguyên bản đang chạy: " .. tostring(err):sub(1, 90) end
    local cur = io.open(dir .. "/main.lua", "rb")
    local old = cur and cur:read("*a")
    if cur then cur:close() end
    if old == body then return true, "Đã là bản mới nhất.", false end
    if old then
        local b = io.open("/mnt/us/vn_dash/main_backup.lua", "wb")
        if b then
            b:write(old)
            b:close()
        end
    end
    local out = io.open(dir .. "/main.lua", "wb")
    if not out then return false, "Không ghi được file plugin." end
    out:write(body)
    out:close()
    return true, "Đã cập nhật xong. Đang khởi động lại KOReader…", true
end

function VNDash:doUpdate()
    local it = { title = "Cập nhật ứng dụng", source = "Phiên bản hiện tại: " .. BUILD, when = "", loading = true, fetched = true }
    self.detail = it
    UIManager:setDirty(self, "full")
    UIManager:scheduleIn(0.4, function()
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:runWhenOnline(function()
            local ok, r1, r2, r3 = pcall(self_update)
            it.loading = false
            if not ok then
                it.sections = { { "Kết quả", "Lỗi: " .. tostring(r1):sub(1, 120) } }
            else
                it.sections = { { "Kết quả", r2 or "" } }
            end
            UIManager:setDirty(self, "full")
            if ok and r1 and r3 then
                UIManager:scheduleIn(2, function()
                    local okd, Device = pcall(require, "device")
                    self:close()
                    if okd and Device and Device.canRestart and Device:canRestart() then
                        UIManager:restartKOReader()
                    end
                end)
            end
        end)
    end)
end

function VNDash:openProfile()
    local s = self.stock
    if not s or type(s.d) ~= "table" then return end
    local d = s.d
    local sym = d.stockSymbol
    local it = { title = (d.companyNameVi or sym) .. " (" .. sym .. ")", source = "Hồ sơ doanh nghiệp", when = "", fetched = true }
    local st = PROFILES[sym]
    local function build(p)
        local secs = { { "Sàn niêm yết", string.upper(d.exchange or "") } }
        if st then
            secs[#secs + 1] = { "Ngành", st[1] }
            secs[#secs + 1] = { "Bán gì / làm gì", st[2] }
            secs[#secs + 1] = { "Dễ nhớ", st[3] }
        else
            if p and p.industry then secs[#secs + 1] = { "Ngành", p.industry } end
            if p and p.text then
                secs[#secs + 1] = { "Giới thiệu", cut_sent(p.text, 520) }
            else
                secs[#secs + 1] = { "Giới thiệu", "Chưa có mô tả cho mã này trong dữ liệu có sẵn." }
            end
        end
        return secs
    end
    if st or s.profile then
        it.sections = s.profile or build(nil)
        self.detail = it
        UIManager:setDirty(self, "full")
        return
    end
    it.loading = true
    self.detail = it
    UIManager:setDirty(self, "full")
    UIManager:scheduleIn(0.3, function()
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:runWhenOnline(function()
            local ok, p = pcall(load_profile, sym, d)
            it.sections = build(ok and p or nil)
            s.profile = it.sections
            it.loading = false
            UIManager:setDirty(self, "ui")
        end)
    end)
end

function VNDash:openIndexInfo()
    local it = self.indices[self.index_open or 1]
    if not it then return end
    local d = it.data
    local secs = {}
    if d then
        local mv = (d.change or 0) > 0 and "tăng " or ((d.change or 0) < 0 and "giảm " or "đi ngang ")
        local line = "Chỉ số " .. mv .. fmt(math.abs(d.change or 0), 2) .. " điểm (" .. fmt(math.abs(d.pct or 0), 2) .. "%). " ..
            d.adv .. " mã tăng, " .. d.dec .. " mã giảm"
        if d.adv > d.dec then line = line .. ": phần đông cổ phiếu xanh."
        elseif d.dec > d.adv then line = line .. ": phần đông cổ phiếu đỏ."
        else line = line .. "." end
        secs[#secs + 1] = { "Hôm nay", line }
    end
    for _, x in ipairs(INDEX_INFO[it.name] or {}) do secs[#secs + 1] = x end
    if #secs == 0 then secs[1] = { "Giới thiệu", "Chưa có mô tả cho chỉ số này." } end
    self.detail = { title = it.name, source = "Giới thiệu chỉ số", when = "", sections = secs, fetched = true }
    UIManager:setDirty(self, "full")
end

function VNDash:openSearch()
    local dlg
    dlg = InputDialog:new{
        title = "Tra mã cổ phiếu",
        input = "",
        input_hint = "Ví dụ: FPT, VPS, HPG",
        buttons = {
            {
                { text = "Huỷ", id = "close", callback = function() UIManager:close(dlg) end },
                { text = "Tra cứu", is_enter_default = true, callback = function()
                    local s = dlg:getInputText() or ""
                    UIManager:close(dlg)
                    self:lookup(s)
                end },
            },
        },
    }
    UIManager:show(dlg)
    dlg:onShowKeyboard()
end

function VNDash:lookup(raw, back)
    local sym = (raw or ""):upper():gsub("[^A-Z0-9]", "")
    self.tab = "stocks"
    self.back = back
    if #sym < 2 or #sym > 12 then
        self.mode = "stock"
        self.stock = { error = "Mã không hợp lệ" }
        UIManager:setDirty(self, "ui")
        return
    end
    self.mode = "loading"
    self.loading = sym
    UIManager:setDirty(self, "ui")
    UIManager:scheduleIn(0.3, function()
        local NetworkMgr = require("ui/network/manager")
        NetworkMgr:runWhenOnline(function()
            local ok, err = pcall(function()
                local j = fetch_json(API .. "/stock/" .. sym)
                local d = j and j.data
                if type(d) ~= "table" or not d.stockSymbol then
                    self.stock = { error = "Không tìm thấy mã " .. sym }
                else
                    self.stock = { d = d, news = fetch_news(sym) }
                end
            end)
            if not ok then
                log("lookup error: " .. tostring(err))
                self.stock = { error = "Lỗi khi tải dữ liệu" }
            end
            self.mode = "stock"
            UIManager:setDirty(self, "full")
        end)
    end)
end

-- ----- vẽ màn hình -----
function VNDash:paintTo(bb, x, y)
    local W, H = self.dimen.w, self.dimen.h
    self.hits = {}
    bb:paintRect(x, y, W, H, WHITE)
    local ok, err = pcall(function()
        self:drawHeader(bb, W, H)
        self:drawTabs(bb, W)
        if self.tab == "stocks" then
            if self.mode == "overview" then
                self:drawOverview(bb, W, H)
            elseif self.mode == "watch" then
                self:drawWatch(bb, W, H)
            elseif self.mode == "top" then
                self:drawTop(bb, W, H)
            elseif self.mode == "sector" then
                self:drawSector(bb, W, H)
            elseif self.mode == "heat" then
                self:drawHeat(bb, W, H)
            elseif self.mode == "index" then
                self:drawIndexDetail(bb, W, H)
            elseif self.mode == "loading" then
                txt(bb, "Đang tải " .. tostring(self.loading) .. "…", math.floor(W / 2), math.floor(H / 2) - 30, 48, { center = true, bold = true })
            else
                self:drawStock(bb, W, H)
            end
        elseif self.tab == "gold" then
            self:drawGold(bb, W, H)
        elseif self.tab == "news" then
            self:drawNews(bb, W, H)
        elseif self.tab == "weather" then
            self:drawWeather(bb, W, H)
        else
            self:drawCalendar(bb, W, H)
        end
        self:drawButtons(bb, W, H)
        if self.detail then self:drawDetail(bb, W, H) end
    end)
    if not ok then
        log("paint error: " .. tostring(err))
        txt(bb, "Lỗi hiển thị: " .. tostring(err), 40, 260, 24, { max_width = W - 80 })
    end
end

function VNDash:drawHeader(bb, W, H)
    local mx = 36
    bb:paintRoundedRect(mx, 30, W - 2 * mx, 84, BLACK, 24)
    local title = "VIBE CODE"
    for _, t in ipairs(TABS) do
        if t[1] == self.tab then title = t[2] end
    end
    txt(bb, title, mx + 34, 42, 44, { bold = true, color = WHITE })
    local right
    if self.tab == "stocks" then
        right = is_trading_time() and "Đang giao dịch" or "Ngoài giờ giao dịch"
    else
        right = os.date("%H:%M  %d/%m/%Y")
    end
    if self.updated and W > 1500 and self.tab ~= "calendar" then right = right .. "  ·  cập nhật " .. self.updated end
    txt(bb, right, W - mx - 34, 56, 26, { right = true, color = WHITE })
end

function VNDash:drawTabs(bb, W)
    local mx, ty, th, gap = 36, 128, 62, 12
    local n = #TABS + 1
    local tw = math.floor((W - 2 * mx - (n - 1) * gap) / n)
    local fs = (tw >= 200) and 28 or 22
    for i, t in ipairs(TABS) do
        local tx = mx + (i - 1) * (tw + gap)
        if self.tab == t[1] then
            bb:paintRoundedRect(tx, ty, tw, th, BLACK, 22)
            txt(bb, t[2], tx + math.floor(tw / 2), ty + 14, fs, { center = true, bold = true, color = WHITE })
        else
            bb:paintBorder(tx, ty, tw, th, 3, BLACK, 22)
            txt(bb, t[2], tx + math.floor(tw / 2), ty + 14, fs, { center = true, bold = true })
        end
        local key = t[1]
        self.hits[#self.hits + 1] = { x = tx, y = ty, w = tw, h = th, fn = function()
            if self.tab ~= key then self:go(key, key == "stocks" and "overview" or nil) end
        end }
    end
    local ex = mx + #TABS * (tw + gap)
    bb:paintBorder(ex, ty, tw, th, 3, Blitbuffer.COLOR_GRAY_6, 22)
    txt(bb, "THOÁT", ex + math.floor(tw / 2), ty + 14, fs, { center = true, bold = true, color = Blitbuffer.COLOR_GRAY_6 })
    self.hits[#self.hits + 1] = { x = ex, y = ty, w = tw, h = th, fn = function() self:close() end }
end

function VNDash:buttonList()
    if self.tab == "stocks" and self.mode == "index" then
        return {
            { "< QUAY LẠI", function() self:go("stocks", "overview") end, true, 1.3 },
            { "GIỚI THIỆU", function() self:openIndexInfo() end, true, 1.2 },
            { "LÀM MỚI", function() self:refresh(true) end, false, 1 },
        }
    end
    if self.tab == "stocks" then
        local list = { { "TRA MÃ", function() self:openSearch() end, true, 1.3 } }
        if self.mode == "stock" and self.stock and type(self.stock.d) == "table" then
            list[#list + 1] = { "GIỚI THIỆU", function() self:openProfile() end, true, 1.2 }
        end
        if self.mode == "stock" and self.back then
            local bm = self.back
            list[#list + 1] = { "< QUAY LẠI", function() self:go("stocks", bm) end, true, 1.3 }
        end
        local pages = { { "overview", "TỔNG QUAN" }, { "watch", "DANH MỤC" }, { "top", "TOP MÃ" }, { "sector", "NGÀNH" }, { "heat", "BẢN ĐỒ" } }
        for _, p in ipairs(pages) do
            local m = p[1]
            list[#list + 1] = { p[2], function() self:go("stocks", m) end, (self.mode == m), 1 }
        end
        if self.mode == "heat" then
            local allm = (self.heat_mode == "all")
            list[#list + 1] = { allm and "THEO NGÀNH" or "TOÀN TT", function()
                self.heat_mode = allm and "sector" or "all"
                UIManager:setDirty(self, "full")
            end, true, 1.2 }
            local byval = (self.heat_metric == "value")
            list[#list + 1] = { byval and "VỐN HOÁ" or "GTGD", function()
                self.heat_metric = byval and "cap" or "value"
                UIManager:setDirty(self, "full")
            end, true, 1.1 }
        end
        if self.mode == "sector" then
            local detail = self.sec_open ~= nil
            if detail then
                list[#list + 1] = { "< DS NGÀNH", function()
                    self.sec_open = nil
                    UIManager:setDirty(self, "full")
                end, true, 1.2 }
            end
            list[#list + 1] = { "< TRƯỚC", function()
                if detail then
                    if self.sec_dpage > 1 then self.sec_dpage = self.sec_dpage - 1 end
                elseif self.sec_page > 1 then
                    self.sec_page = self.sec_page - 1
                end
                UIManager:setDirty(self, "full")
            end, false, 0.9 }
            list[#list + 1] = { "SAU >", function()
                if detail then
                    if self.sec_dpage < (self.sec_dpages or 1) then self.sec_dpage = self.sec_dpage + 1 end
                elseif self.sec_page < (self.sec_pages or 1) then
                    self.sec_page = self.sec_page + 1
                end
                UIManager:setDirty(self, "full")
            end, false, 0.9 }
        end
        if self.mode == "overview" or self.mode == "watch" then
            list[#list + 1] = { "SỬA", function() self:openEdit(self.mode) end, false, 0.8 }
        end
        list[#list + 1] = { "LÀM MỚI", function() self:refresh(true) end, false, 1 }
        return list
    elseif self.tab == "news" then
        local list = {}
        for i, c in ipairs(cfg.news) do
            local idx = i
            list[#list + 1] = { c.label, function()
                self.news_cat = idx
                UIManager:setDirty(self, "full")
                if not self.news[idx] then self:refresh(true) end
            end, (idx == self.news_cat), 1 }
        end
        local key = "news" .. self.news_cat
        list[#list + 1] = { "< TRƯỚC", function() self:page(key, -1) end, false, 0.9 }
        list[#list + 1] = { "SAU >", function() self:page(key, 1) end, false, 0.9 }
        list[#list + 1] = { "LÀM MỚI", function() self:refresh(true) end, false, 1 }
        return list
    elseif self.tab == "gold" then
        return {
            { "< TRƯỚC", function() self:page("gold", -1) end, false, 0.9 },
            { "SAU >", function() self:page("gold", 1) end, false, 0.9 },
            { "LÀM MỚI", function() self:refresh(true) end, true, 1 },
        }
    elseif self.tab == "weather" then
        return {
            { "TỔNG QUAN", function() self.wmode = "overview"; UIManager:setDirty(self, "full") end, (self.wmode ~= "hourly"), 1 },
            { "THEO GIỜ", function() self.wmode = "hourly"; UIManager:setDirty(self, "full") end, (self.wmode == "hourly"), 1 },
            { "LÀM MỚI", function() self:refresh(true) end, false, 1 },
        }
    elseif self.tab == "calendar" then
        return {
            { "CẬP NHẬT APP", function() self:doUpdate() end, false, 1.3 },
            { "LÀM MỚI", function() UIManager:setDirty(self, "full") end, true, 1 },
        }
    end
    return { { "LÀM MỚI", function() self:refresh(true) end, true, 1 } }
end

function VNDash:drawButtons(bb, W, H)
    local mx, bh, gap = 36, 84, 20
    local by = H - 30 - bh - 22
    local list = self:buttonList()
    local totw = 0
    for _, b in ipairs(list) do totw = totw + b[4] end
    local avail = W - 2 * mx - (#list - 1) * gap
    local bx = mx
    local bfs = (#list >= 9) and 21 or (#list >= 8) and 23 or ((#list >= 7) and 27 or 32)
    local boff = (#list >= 8) and 28 or ((#list >= 7) and 24 or 20)
    for _, b in ipairs(list) do
        local bw = math.floor(avail * b[4] / totw)
        if b[3] then
            bb:paintRoundedRect(bx, by, bw, bh, BLACK, 30)
            txt(bb, b[1], bx + math.floor(bw / 2), by + boff, bfs, { center = true, bold = true, color = WHITE })
        else
            bb:paintBorder(bx, by, bw, bh, 4, BLACK, 30)
            txt(bb, b[1], bx + math.floor(bw / 2), by + boff, bfs, { center = true, bold = true })
        end
        self.hits[#self.hits + 1] = { x = bx, y = by, w = bw, h = bh, fn = b[2] }
        bx = bx + bw + gap
    end
    txt(bb, "Nguồn: SSI iBoard · PNJ · DOJI · BTMC · VnExpress · Tuổi Trẻ · VietNamNet · Google News · Open-Meteo", math.floor(W / 2), H - 32, 18, { center = true, color = Blitbuffer.COLOR_GRAY_5 })
end

local function area(H)
    return 206, H - 30 - 84 - 22 - 20
end

local function msg(bb, W, top, bottom, text, px)
    txt(bb, text, math.floor(W / 2), math.floor((top + bottom) / 2) - 24, px or 40, { center = true, bold = true })
end

-- ----- phân trang / chi tiết tin / từ vựng -----
function VNDash:navstate(key)
    self.nav = self.nav or {}
    local n = self.nav[key]
    if not n then
        n = { start = 1, stack = {}, drawn = 0, total = 0 }
        self.nav[key] = n
    end
    return n
end

function VNDash:page(key, dir)
    local n = self:navstate(key)
    if dir > 0 then
        if n.drawn > 0 and n.start + n.drawn <= n.total then
            n.stack[#n.stack + 1] = n.start
            n.start = n.start + n.drawn
        end
    elseif #n.stack > 0 then
        n.start = table.remove(n.stack)
    end
    UIManager:setDirty(self, "full")
end

function VNDash:openDetail(it)
    self.detail = it
    UIManager:setDirty(self, "full")
    if (it.desc == nil or it.desc == "") and not it.fetched and it.link and it.link ~= "" then
        it.loading = true
        UIManager:scheduleIn(0.3, function()
            local NetworkMgr = require("ui/network/manager")
            NetworkMgr:runWhenOnline(function()
                local ok, d = pcall(fetch_desc, it.link)
                it.desc = (ok and d) or ""
                it.fetched = true
                it.loading = false
                UIManager:setDirty(self, "ui")
            end)
        end)
    end
end

function VNDash:drawDetail(bb, W, H)
    local it = self.detail
    local bw = math.floor(W * 0.86)
    local pad = 44
    local iw = bw - 2 * pad
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    local tb = TextBoxWidget:new{ text = it.title, face = face(38), width = iw, fgcolor = BLACK, bold = true }
    local th = tb:getSize().h
    local parts = {}
    if it.loading then
        parts[1] = { nil, "Đang tải…" }
    elseif it.sections then
        for _, sc in ipairs(it.sections) do parts[#parts + 1] = { sc[1], sc[2] } end
    elseif it.desc and it.desc ~= "" then
        parts[1] = { nil, it.desc }
    else
        parts[1] = { nil, "Bài này không có phần tóm tắt trong nguồn tin." }
    end
    local total = 32 + th + 8 + 44 + 3 + 22 + 26 + 68 + 26
    for _, pt in ipairs(parts) do
        pt.w = TextBoxWidget:new{ text = pt[2], face = face(30), width = iw, fgcolor = BLACK }
        pt.h = pt.w:getSize().h
        total = total + (pt[1] and 36 or 0) + pt.h + 20
    end
    local bh = math.min(math.max(total, math.floor(H * 0.35)), math.floor(H * 0.9))
    local bx, by = math.floor((W - bw) / 2), math.floor((H - bh) / 2)
    bb:paintRect(bx - 8, by - 8, bw + 16, bh + 16, WHITE)
    bb:paintBorder(bx, by, bw, bh, 5, BLACK, 30)
    tb:paintTo(bb, bx + pad, by + 32)
    tb:free()
    local y = by + 32 + th + 8
    local meta = it.source or ""
    if it.when and it.when ~= "" then meta = (meta ~= "" and (meta .. "  ·  ") or "") .. it.when end
    txt(bb, meta, bx + pad, y, 24, { color = GRAY5 })
    y = y + 44
    bb:paintRect(bx + pad, y, iw, 3, BLACK)
    y = y + 22
    local limit = by + bh - 26 - 68 - 14
    for _, pt in ipairs(parts) do
        if pt[1] and y + 36 + pt.h <= limit + 40 then
            txt(bb, pt[1], bx + pad, y, 24, { bold = true, color = GRAY5 })
            y = y + 36
        end
        if y + pt.h <= limit + 40 then pt.w:paintTo(bb, bx + pad, y) end
        pt.w:free()
        y = y + pt.h + 20
    end
    local cw, ch = 220, 68
    local cx, cy = bx + bw - pad - cw, by + bh - ch - 26
    bb:paintRoundedRect(cx, cy, cw, ch, BLACK, 26)
    txt(bb, "ĐÓNG", cx + math.floor(cw / 2), cy + 16, 30, { center = true, bold = true, color = WHITE })
    self.hits = { { x = 0, y = 0, w = W, h = H, fn = function()
        self.detail = nil
        UIManager:setDirty(self, "full")
    end } }
end

function VNDash:word_state()
    local today = os.date("%Y%m%d")
    if self.wstate and self.wstate.day == today then return self.wstate end
    local off = 0
    local f = io.open(WORDFILE, "r")
    if f then
        local s = f:read("*a")
        f:close()
        local d, o = s:match("(%d+)%s+(%d+)")
        if d == today then off = tonumber(o) or 0 end
    end
    self.wstate = { day = today, off = off }
    return self.wstate
end

function VNDash:next_word()
    local st = self:word_state()
    st.off = st.off + 1
    local f = io.open(WORDFILE, "w")
    if f then
        f:write(st.day .. " " .. st.off .. "\n")
        f:close()
    end
    UIManager:setDirty(self, "ui")
end

function VNDash:word_today()
    local st = self:word_state()
    return WORDS[(tonumber(os.date("%j")) + st.off) % #WORDS + 1]
end

function VNDash:sector_list()
    local list = (self.top and self.top.sectors) or {}
    local now = os.time()
    local so = self.sec_order
    if not so or now - so.ts >= 7200 or #so.names == 0 then
        local tmp = {}
        for _, s in ipairs(list) do tmp[#tmp + 1] = s end
        table.sort(tmp, function(a, b) return a.score > b.score end)
        local names = {}
        for i, s in ipairs(tmp) do names[i] = s.name end
        so = { ts = now, names = names }
        self.sec_order = so
    end
    local byname, used, out = {}, {}, {}
    for _, s in ipairs(list) do byname[s.name] = s end
    for _, nm in ipairs(so.names) do
        if byname[nm] then
            out[#out + 1] = byname[nm]
            used[nm] = true
        end
    end
    local extra = {}
    for _, s in ipairs(list) do
        if not used[s.name] then extra[#extra + 1] = s end
    end
    table.sort(extra, function(a, b) return a.score > b.score end)
    for _, s in ipairs(extra) do out[#out + 1] = s end
    return out, so.ts
end

function VNDash:drawSector(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    if not self.top then
        msg(bb, W, top, bottom, self.busy and "Đang tải nhóm ngành (HOSE)…" or "Không tải được dữ liệu. Bấm LÀM MỚI.", 38)
        return
    end
    local list, ts = self:sector_list()
    if self.sec_open then
        local found
        for _, s in ipairs(list) do if s.name == self.sec_open then found = s end end
        if found then
            self:drawSectorDetail(bb, W, H, found, top, bottom)
            return
        end
        self.sec_open = nil
    end
    bb:paintBorder(mx, top, W - 2 * mx, bottom - top, 3, BLACK, 26)
    local ix, iw = mx + 30, W - 2 * mx - 60
    txt(bb, "NHÓM NGÀNH · HOSE", ix, top + 16, 30, { bold = true })
    txt(bb, "Xếp theo độ nóng (GTGD + KLGD) · thứ hạng chốt lúc " .. os.date("%H:%M", ts) .. ", đổi mỗi 2 giờ",
        ix + iw, top + 24, 20, { right = true, color = GRAY5 })
    local hy = top + 68
    local c_name = ix + math.floor(iw * 0.05)
    local c_bar = ix + math.floor(iw * 0.30)
    local bar_w = math.floor(iw * 0.12)
    local c_val = ix + math.floor(iw * 0.61)
    local c_vol = ix + math.floor(iw * 0.75)
    local c_pct = ix + math.floor(iw * 0.88)
    local c_ad = ix + iw
    txt(bb, "#", ix + 6, hy, 20, { color = GRAY5, bold = true })
    txt(bb, "NGÀNH", c_name, hy, 20, { color = GRAY5, bold = true })
    txt(bb, "ĐỘ NÓNG", c_bar, hy, 20, { color = GRAY5, bold = true })
    txt(bb, "GTGD (TỶ)", c_val, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "KL (TR CP)", c_vol, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "% TB", c_pct, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "TĂNG / GIẢM", c_ad, hy, 20, { right = true, color = GRAY5, bold = true })
    bb:paintRect(ix, hy + 32, iw, 3, BLACK)
    local rowh = 74
    local first_y = hy + 46
    local per = math.max(1, math.floor((bottom - 16 - first_y) / rowh))
    local pages = math.max(1, math.ceil(#list / per))
    if self.sec_page > pages then self.sec_page = pages end
    if self.sec_page < 1 then self.sec_page = 1 end
    self.sec_pages = pages
    local maxshare = 0.0001
    for _, s in ipairs(list) do if s.share > maxshare then maxshare = s.share end end
    for k = 1, per do
        local i = (self.sec_page - 1) * per + k
        local s = list[i]
        if not s then break end
        local ry = first_y + (k - 1) * rowh
        if k > 1 then bb:paintRect(ix, ry - 6, iw, 1, Blitbuffer.COLOR_GRAY_B) end
        self.hits[#self.hits + 1] = { x = ix, y = ry - 6, w = iw, h = rowh, fn = function()
            self.sec_open = s.name
            self.sec_dpage = 1
            UIManager:setDirty(self, "full")
        end }
        txt(bb, tostring(i), ix + 6, ry + 14, 30, { bold = true })
        txt(bb, s.name, c_name, ry + 2, 30, { bold = true, max_width = c_bar - c_name - 14 })
        local syms = {}
        for q = 1, math.min(6, #s.rows) do syms[q] = s.rows[q].sym end
        txt(bb, table.concat(syms, " · "), c_name, ry + 38, 20, { color = GRAY5, max_width = c_bar - c_name - 14 })
        local bar_y = ry + 20
        bb:paintRect(c_bar, bar_y, bar_w, 24, Blitbuffer.COLOR_GRAY_E)
        local fw = math.max(3, math.floor(bar_w * s.share / maxshare))
        bb:paintRect(c_bar, bar_y, fw, 24, BLACK)
        txt(bb, fmt(s.share * 100, 1) .. "%", c_bar + bar_w + 10, ry + 20, 22, { color = GRAY5 })
        txt(bb, fmt(s.value / 1e9, 0), c_val, ry + 14, 30, { right = true, bold = true })
        txt(bb, fmt(s.vol / 1e6, 1), c_vol, ry + 14, 30, { right = true })
        local pw_ = txt(bb, sfmt(s.pct, 2) .. "%", c_pct, ry + 14, 30, { right = true, bold = true })
        local kind = kind_of(s.pct)
        if kind == "up" then
            tri(bb, c_pct - pw_ - 20, ry + 32, 16, true, BLACK)
        elseif kind == "down" then
            tri(bb, c_pct - pw_ - 20, ry + 32, 16, false, BLACK)
        end
        txt(bb, s.adv .. " / " .. s.dec, c_ad, ry + 14, 30, { right = true, bold = true })
    end
    txt(bb, "Bấm vào ngành để xem top mã · Trang " .. self.sec_page .. "/" .. pages .. " · " .. #list .. " nhóm · " .. tostring(self.top.mapped or 0) .. " mã HOSE",
        ix + iw, bottom - 34, 20, { right = true, color = GRAY5 })
end

function VNDash:drawSectorDetail(bb, W, H, s, top, bottom)
    local mx = 36
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    bb:paintBorder(mx, top, W - 2 * mx, bottom - top, 3, BLACK, 26)
    local ix, iw = mx + 30, W - 2 * mx - 60
    txt(bb, "NGÀNH " .. string.upper(s.name) .. " · TOP MÃ THEO GTGD", ix, top + 16, 30, { bold = true, max_width = math.floor(iw * 0.62) })
    local sum = "GTGD " .. fmt(s.value / 1e9, 0) .. " tỷ · KL " .. fmt(s.vol / 1e6, 1) .. " tr cp · " .. sfmt(s.pct, 2) .. "% · " .. s.adv .. " tăng / " .. s.dec .. " giảm"
    txt(bb, sum, ix + iw, top + 24, 21, { right = true, color = GRAY5 })
    local hy = top + 68
    local c_sym = ix + math.floor(iw * 0.05)
    local c_price = ix + math.floor(iw * 0.36)
    local c_pct = ix + math.floor(iw * 0.54)
    local c_val = ix + math.floor(iw * 0.72)
    local c_vol = ix + math.floor(iw * 0.87)
    local c_net = ix + iw
    txt(bb, "#", ix + 6, hy, 20, { color = GRAY5, bold = true })
    txt(bb, "MÃ", c_sym, hy, 20, { color = GRAY5, bold = true })
    txt(bb, "GIÁ (NGHÌN ĐỒNG)", c_price, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "% THAY ĐỔI", c_pct, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "GTGD (TỶ)", c_val, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "KL (TR CP)", c_vol, hy, 20, { right = true, color = GRAY5, bold = true })
    txt(bb, "NN RÒNG (TỶ)", c_net, hy, 20, { right = true, color = GRAY5, bold = true })
    bb:paintRect(ix, hy + 32, iw, 3, BLACK)
    local rows = {}
    for _, r in ipairs(s.rows) do rows[#rows + 1] = r end
    table.sort(rows, function(a, b) return a.value > b.value end)
    local rowh = 62
    local first_y = hy + 46
    local per = math.max(1, math.floor((bottom - 16 - first_y) / rowh))
    local pages = math.max(1, math.ceil(#rows / per))
    if self.sec_dpage > pages then self.sec_dpage = pages end
    if self.sec_dpage < 1 then self.sec_dpage = 1 end
    self.sec_dpages = pages
    for k = 1, per do
        local i = (self.sec_dpage - 1) * per + k
        local r = rows[i]
        if not r then break end
        local ry = first_y + (k - 1) * rowh
        if k > 1 then bb:paintRect(ix, ry - 6, iw, 1, Blitbuffer.COLOR_GRAY_B) end
        local sym_ = r.sym
        self.hits[#self.hits + 1] = { x = ix, y = ry - 6, w = iw, h = rowh, fn = function() self:lookup(sym_, "sector") end }
        txt(bb, tostring(i), ix + 6, ry + 10, 26, { color = GRAY5 })
        txt(bb, r.sym, c_sym, ry + 6, 32, { bold = true })
        txt(bb, fmt(r.price / 1000, 2), c_price, ry + 10, 28, { right = true })
        local pw_ = txt(bb, sfmt(r.pct, 2) .. "%", c_pct, ry + 10, 28, { right = true, bold = true })
        local kind = kind_of(r.change)
        if kind == "up" then
            tri(bb, c_pct - pw_ - 18, ry + 26, 14, true, BLACK)
        elseif kind == "down" then
            tri(bb, c_pct - pw_ - 18, ry + 26, 14, false, BLACK)
        end
        txt(bb, fmt(r.value / 1e9, 0), c_val, ry + 10, 28, { right = true, bold = true })
        txt(bb, fmt(r.vol / 1e6, 2), c_vol, ry + 10, 28, { right = true })
        txt(bb, sfmt(r.net, 1), c_net, ry + 10, 28, { right = true })
    end
    txt(bb, "Bấm vào mã để xem chi tiết · Trang " .. self.sec_dpage .. "/" .. pages .. " · " .. #rows .. " mã", ix + iw, bottom - 34, 20, { right = true, color = GRAY5 })
end

function VNDash:drawHourly(bb, W, H, top, bottom, data)
    local mx = 36
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    bb:paintBorder(mx, top, W - 2 * mx, bottom - top, 3, BLACK, 26)
    local ix, iw = mx + 36, W - 2 * mx - 72
    txt(bb, "DỰ BÁO THEO GIỜ · " .. tostring(cfg.place or ""), ix, top + 18, 32, { bold = true })
    txt(bb, "Thanh đen = khả năng mưa (0–100%)", ix + iw, top + 28, 22, { right = true, color = GRAY5 })
    bb:paintRect(ix, top + 70, iw, 3, BLACK)
    local hr = data.w.hourly
    local n = (hr and hr.time) and math.min(24, #hr.time) or 0
    if n == 0 then
        msg(bb, W, top, bottom, "Chưa có dự báo theo giờ", 36)
        return
    end
    local cols = (W > H) and 3 or 2
    local per = math.ceil(n / cols)
    local cw = math.floor(iw / cols)
    local rowh = math.floor((bottom - top - 90 - 14) / per)
    for i = 1, n do
        local col = math.floor((i - 1) / per)
        local row = (i - 1) % per
        local cx = ix + col * cw
        local cy = top + 82 + row * rowh
        if row > 0 then bb:paintRect(cx + 6, cy, cw - 30, 1, Blitbuffer.COLOR_GRAY_B) end
        local hh = tonumber(hr.time[i]:match("T(%d+):")) or 0
        local midy = cy + math.floor(rowh / 2)
        txt(bb, (i == 1) and "Nay" or (hh .. "h"), cx + 8, midy - 20, 32, { bold = true })
        wx_icon(bb, cx + 138, midy, math.min(rowh - 10, 64), wx_kind(hr.weather_code and hr.weather_code[i]))
        txt(bb, fmt(hr.temperature_2m and hr.temperature_2m[i] or 0, 0) .. "°", cx + 190, midy - 20, 34, { bold = true })
        local pr = (hr.precipitation_probability and hr.precipitation_probability[i]) or 0
        local bx0 = cx + 280
        local bw = cw - 280 - 110
        if bw < 60 then bw = 60 end
        bb:paintBorder(bx0, midy - 12, bw, 24, 2, BLACK, 0)
        local fw = math.floor((bw - 4) * pr / 100)
        if fw > 0 then bb:paintRect(bx0 + 2, midy - 10, fw, 20, BLACK) end
        txt(bb, fmt(pr, 0) .. "%", cx + cw - 24, midy - 17, 28, { right = true, bold = true })
    end
end

function VNDash:drawNews(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    bb:paintBorder(mx, top, W - 2 * mx, bottom - top, 3, BLACK, 26)
    local items = self.news[self.news_cat]
    if not items then
        msg(bb, W, top, bottom, self.busy and "Đang tải tin…" or "Chưa có dữ liệu")
        return
    end
    if #items == 0 then
        msg(bb, W, top, bottom, "Không tải được tin. Kiểm tra Wi-Fi rồi bấm LÀM MỚI.", 32)
        return
    end
    local nv = self:navstate("news" .. self.news_cat)
    if nv.start > #items then nv.start = 1; nv.stack = {} end
    nv.total = #items
    nv.drawn = headlines(bb, items, mx, top, W - 2 * mx, bottom - top, (W > H) and 2 or 1, 32, nv.start, self.hits,
        function(it) self:openDetail(it) end)
    txt(bb, "Tin " .. nv.start .. "–" .. (nv.start + nv.drawn - 1) .. " / " .. #items .. "  ·  bấm vào tin để xem tóm tắt",
        W - mx - 30, bottom - 36, 20, { right = true, color = Blitbuffer.COLOR_GRAY_5 })
end

function VNDash:drawWatch(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local rows = self.watch
    if not rows then
        msg(bb, W, top, bottom, self.busy and "Đang tải danh mục…" or "Không tải được danh mục. Bấm LÀM MỚI.", 38)
        return
    end
    local landscape = W > H
    local cols = landscape and 2 or 1
    local gap = 14
    local per = math.ceil(#rows / cols)
    local cw = math.floor((W - 2 * mx - (cols - 1) * 24) / cols)
    local ch = math.floor((bottom - top - (per - 1) * gap) / per)
    local u = ch / 150
    local function P(n) return math.floor(n * u + 0.5) end
    for i, r in ipairs(rows) do
        local col = math.floor((i - 1) / per)
        local row = (i - 1) % per
        local cx = mx + col * (cw + 24)
        local cy = top + row * (ch + gap)
        bb:paintBorder(cx, cy, cw, ch, 2, BLACK, P(20))
        local sym_ = r.sym
        self.hits[#self.hits + 1] = { x = cx, y = cy, w = cw, h = ch, fn = function() self:lookup(sym_, "watch") end }
        txt(bb, r.sym, cx + P(26), cy + P(6), P(66), { bold = true })
        if r.missing then
            txt(bb, "Không có dữ liệu", cx + P(26), cy + P(76), P(30), { color = Blitbuffer.COLOR_GRAY_5 })
        else
            local kind = kind_of(r.change)
            txt(bb, fmt(r.price / 1000, 2), cx + P(26), cy + P(92), P(40), { color = Blitbuffer.COLOR_GRAY_6 })
            local bw, bh = P(230), P(58)
            local pct = sfmt(r.pct, 2) .. "%"
            badge(bb, cx + cw - bw - P(22), cy + P(16), bw, bh, kind, pct, P(30))
            txt(bb, sfmt(r.change / 1000, 2), cx + cw - P(30), cy + P(84), P(28), { right = true, bold = true })
            txt(bb, "GTGD " .. fmt(r.value / 1e9, 0) .. " tỷ", cx + cw - P(30), cy + P(116), P(22), { right = true, color = Blitbuffer.COLOR_GRAY_5 })
        end
    end
end

-- số cổ phiếu niêm yết (tỷ cp, xấp xỉ) để ước tính vốn hoá; API SSI không trả số này
local SHARES = {
    VIC = 7.7, VHM = 4.1, VRE = 2.28, VPL = 2.4, BCM = 1.03, KBC = 0.96, NVL = 2.0, KDH = 1.0, DXG = 0.9, NLG = 0.4, PDR = 0.99, CII = 0.25, IDC = 0.33, SZC = 0.1, SIP = 0.1,
    VCB = 8.36, BID = 7.03, CTG = 5.37, TCB = 7.08, MBB = 7.9, VPB = 7.93, ACB = 5.15, STB = 1.89, HDB = 3.5, TPB = 2.2, VIB = 3.0, SHB = 3.6, LPB = 3.0, MSB = 2.0, SSB = 2.95, OCB = 2.47, EIB = 1.84, NAB = 1.5, BVH = 0.74,
    SSI = 2.0, VND = 1.5, VCI = 0.6, HCM = 0.7, VIX = 1.5, SHS = 1.2, MBS = 0.6,
    HPG = 7.67, HSG = 0.6, NKG = 0.45, FPT = 1.7, CMG = 0.3, MWG = 1.47, FRT = 0.14, PNJ = 0.34, DGW = 0.2,
    VNM = 2.09, MSN = 1.43, SAB = 1.28, MCH = 0.7, KDC = 0.26, SBT = 0.7, QNS = 0.36, DBC = 0.38, HAG = 1.0,
    GAS = 2.4, PLX = 1.27, PVD = 0.55, PVS = 0.48, BSR = 5.8, OIL = 1.0, POW = 2.34, REE = 0.46, GEG = 0.35, PGV = 1.0,
    VJC = 0.54, HVN = 2.2, GMD = 0.3, HAH = 0.12, VSC = 0.1, VHC = 0.22, ANV = 0.13, DGC = 0.38, DPM = 0.39, DCM = 0.53,
    GVR = 4.0, PHR = 0.14, DRC = 0.12, DHG = 0.13, IMP = 0.07, TRA = 0.05, VCG = 0.56, CTD = 0.1, HBC = 0.35, TNG = 0.12, MSH = 0.05, TCM = 0.09, GEX = 0.9, GEE = 0.35, TCH = 0.8, VGC = 0.45, VPI = 0.2, VCK = 0.25, DMX = 0.5,
}
local function heat_size(r, metric)
    if metric == "value" then return r.value or 0 end
    local sh = SHARES[r.sym] or 0.06
    return sh * 1e9 * (r.price or 0)
end

-- bản đồ nhiệt: treemap theo vốn hoá (ước tính) hoặc GTGD, độ đậm theo % thay đổi
local function squarify(items, x, y, w, h)
    local total = 0
    for _, it in ipairs(items) do total = total + it.v end
    if total <= 0 then return end
    local scale = w * h / total
    local i = 1
    while i <= #items do
        local side = math.min(w, h)
        local row, sum, cur = {}, 0, 1e18
        local j = i
        while j <= #items do
            local a = items[j].v * scale
            row[#row + 1] = a
            local ns = sum + a
            local mx, mn = 0, 1e18
            for _, q in ipairs(row) do
                if q > mx then mx = q end
                if q < mn then mn = q end
            end
            local s2 = side * side
            local wst = math.max(s2 * mx / (ns * ns), ns * ns / (s2 * mn))
            if wst > cur and #row > 1 then
                table.remove(row)
                break
            end
            cur = wst
            sum = ns
            j = j + 1
        end
        local thick = sum / side
        local off = 0
        if w >= h then
            for k = i, j - 1 do
                local len = items[k].v * scale / thick
                items[k].x, items[k].y, items[k].w, items[k].h = x, y + off, thick, len
                off = off + len
            end
            x = x + thick
            w = w - thick
        else
            for k = i, j - 1 do
                local len = items[k].v * scale / thick
                items[k].x, items[k].y, items[k].w, items[k].h = x + off, y, len, thick
                off = off + len
            end
            y = y + thick
            h = h - thick
        end
        i = j
    end
end

function VNDash:heatCell(bb, it)
    local r = it.r
    local x0, y0 = math.floor(it.x + 0.5), math.floor(it.y + 0.5)
    local x1, y1 = math.floor(it.x + it.w + 0.5), math.floor(it.y + it.h + 0.5)
    local cw, ch = x1 - x0 - 3, y1 - y0 - 3
    if cw <= 4 or ch <= 4 then return end
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    local pct = r.pct or 0
    local ap = math.abs(pct)
    local fg = BLACK
    if pct > 0.005 then
        local fill
        if ap >= 4 then fill, fg = BLACK, WHITE
        elseif ap >= 2 then fill, fg = GRAY5, WHITE
        else fill = Blitbuffer.COLOR_GRAY_B end
        bb:paintRect(x0, y0, cw, ch, fill)
    elseif pct < -0.005 then
        bb:paintRect(x0, y0, cw, ch, WHITE)
        local step, th = 12, 1
        if ap >= 4 then step, th = 5, 3 elseif ap >= 2 then step, th = 8, 2 end
        local yy = y0
        while yy < y0 + ch do
            bb:paintRect(x0, yy, cw, math.min(th, y0 + ch - yy), BLACK)
            yy = yy + step
        end
        bb:paintBorder(x0, y0, cw, ch, 2, BLACK, 0)
    else
        bb:paintRect(x0, y0, cw, ch, WHITE)
        bb:paintBorder(x0, y0, cw, ch, 2, BLACK, 0)
    end
    local m = math.min(cw, ch)
    local fs = math.max(16, math.min(42, math.floor(m * 0.3)))
    if cw >= 56 and ch >= 34 then
        local lbl = r.sym
        local cx, cy = x0 + math.floor(cw / 2), y0 + math.floor(ch / 2)
        local pfs = math.max(14, math.floor(fs * 0.7))
        local two = (ch >= fs + pfs + 16) and (cw >= pfs * 4.2)
        local ty = two and (cy - math.floor((fs + pfs) / 2) - 2) or (cy - math.floor(fs * 0.6))
        if pct < -0.005 then
            local pw = math.min(cw - 6, math.max(math.floor(#lbl * fs * 0.7), two and math.floor(pfs * 4.4) or 0) + 14)
            local ph = two and (fs + pfs + 14) or math.floor(fs * 1.3)
            bb:paintRect(cx - math.floor(pw / 2), ty - 2, pw, ph, WHITE)
        end
        txt(bb, lbl, cx, ty, fs, { center = true, bold = true, color = fg })
        if two then
            txt(bb, sfmt(pct, 2) .. "%", cx, ty + fs + 2, pfs, { center = true, color = fg })
        end
    end
    local sym = r.sym
    self.hits[#self.hits + 1] = { x = x0, y = y0, w = cw, h = ch, fn = function() self:lookup(sym, "heat") end }
end

function VNDash:drawHeat(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local t = self.top
    if not t or not t.rows then
        msg(bb, W, top, bottom, self.busy and "Đang tải bản đồ nhiệt (HOSE)…" or "Không tải được dữ liệu. Bấm LÀM MỚI.", 38)
        return
    end
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    local mapw, maph = W - 2 * mx, bottom - top - 36
    local metric = self.heat_metric or "cap"
    if self.heat_mode == "all" then
        local rows = {}
        for _, r in ipairs(t.rows) do
            if (r.value or 0) > 0 then rows[#rows + 1] = r end
        end
        table.sort(rows, function(a, b) return heat_size(a, metric) > heat_size(b, metric) end)
        local items = {}
        for i = 1, math.min(70, #rows) do items[i] = { r = rows[i], v = heat_size(rows[i], metric) } end
        squarify(items, mx, top, mapw, maph)
        for _, it in ipairs(items) do self:heatCell(bb, it) end
    else
        local secs = {}
        for _, sc in ipairs(t.sectors or {}) do
            local tot = 0
            for _, r in ipairs(sc.rows) do
                if (r.value or 0) > 0 then tot = tot + heat_size(r, metric) end
            end
            if tot > 0 then secs[#secs + 1] = { sc = sc, v = tot } end
        end
        table.sort(secs, function(a, b) return a.v > b.v end)
        squarify(secs, mx, top, mapw, maph)
        for _, sec in ipairs(secs) do
            local x0, y0 = math.floor(sec.x + 0.5), math.floor(sec.y + 0.5)
            local x1, y1 = math.floor(sec.x + sec.w + 0.5), math.floor(sec.y + sec.h + 0.5)
            local cw, ch = x1 - x0 - 2, y1 - y0 - 2
            if cw > 20 and ch > 20 then
                bb:paintBorder(x0, y0, cw, ch, 3, BLACK, 0)
                local hh = 0
                if ch >= 70 and cw >= 110 then
                    hh = 26
                    bb:paintRect(x0 + 3, y0 + 3, cw - 6, hh, Blitbuffer.COLOR_GRAY_D)
                    txt(bb, sec.sc.name .. "  " .. sfmt(sec.sc.pct, 2) .. "%", x0 + 8, y0 + 4, 19, { bold = true, max_width = cw - 16 })
                end
                local items = {}
                for _, r in ipairs(sec.sc.rows) do
                    if (r.value or 0) > 0 then items[#items + 1] = { r = r, v = heat_size(r, metric) } end
                end
                table.sort(items, function(a, b) return a.v > b.v end)
                while #items > 16 do table.remove(items) end
                squarify(items, x0 + 3, y0 + 3 + hh, cw - 6, ch - 6 - hh)
                for _, it in ipairs(items) do self:heatCell(bb, it) end
            end
        end
    end
    local mode_txt = (self.heat_mode == "all") and "Toàn thị trường" or "Theo nhóm ngành"
    local met_txt = (metric == "value") and "Cỡ ô = GTGD" or "Cỡ ô = vốn hoá ước tính"
    txt(bb, mode_txt .. "  ·  " .. met_txt .. "  ·  Đặc = tăng (đậm = mạnh)  ·  Sọc = giảm (dày = mạnh)  ·  Bấm ô xem mã", mx, bottom - 30, 21, { color = GRAY5, max_width = mapw })
end

function VNDash:drawTop(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local t = self.top
    if not t then
        msg(bb, W, top, bottom, self.busy and "Đang tải top mã (HOSE)…" or "Không tải được dữ liệu. Bấm LÀM MỚI.", 38)
        return
    end
    local panels = {
        { "TOP TĂNG", t.gain, function(r) return sfmt(r.pct, 2) .. "%" end },
        { "TOP GIẢM", t.lose, function(r) return sfmt(r.pct, 2) .. "%" end },
        { "NN MUA RÒNG", t.fbuy, function(r) return fmt(r.net, 1) .. " tỷ" end },
        { "NN BÁN RÒNG", t.fsell, function(r) return fmt(-r.net, 1) .. " tỷ" end },
    }
    local landscape = W > H
    local gap = 20
    local pcols = landscape and 4 or 2
    local prow = landscape and 1 or 2
    local pw = math.floor((W - 2 * mx - (pcols - 1) * gap) / pcols)
    local ph = math.floor((bottom - top - (prow - 1) * gap) / prow)
    local rowh = 72
    local nrows = math.min(10, math.floor((ph - 96) / rowh))
    for i, p in ipairs(panels) do
        local col = (i - 1) % pcols
        local row = math.floor((i - 1) / pcols)
        local px0 = mx + col * (pw + gap)
        local py0 = top + row * (ph + gap)
        bb:paintBorder(px0, py0, pw, ph, 3, BLACK, 24)
        txt(bb, p[1], px0 + 24, py0 + 18, 28, { bold = true })
        txt(bb, "HOSE", px0 + pw - 24, py0 + 24, 20, { right = true, color = Blitbuffer.COLOR_GRAY_5 })
        bb:paintRect(px0 + 24, py0 + 64, pw - 48, 3, BLACK)
        local list = p[2] or {}
        if #list == 0 then
            txt(bb, "Không có dữ liệu", px0 + 24, py0 + 90, 24, { color = Blitbuffer.COLOR_GRAY_5 })
        end
        for k = 1, math.min(nrows, #list) do
            local r = list[k]
            local ry = py0 + 80 + (k - 1) * rowh
            if k > 1 then bb:paintRect(px0 + 24, ry - 6, pw - 48, 1, Blitbuffer.COLOR_GRAY_B) end
            local sym_ = r.sym
            self.hits[#self.hits + 1] = { x = px0 + 12, y = ry - 6, w = pw - 24, h = rowh, fn = function() self:lookup(sym_, "top") end }
            txt(bb, r.sym, px0 + 24, ry, 32, { bold = true })
            txt(bb, fmt(r.price / 1000, 2), px0 + 24, ry + 38, 20, { color = Blitbuffer.COLOR_GRAY_5 })
            txt(bb, p[3](r), px0 + pw - 24, ry + 12, 30, { right = true, bold = true })
        end
    end
end

function VNDash:drawGold(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local g = self.gold
    if not g then
        msg(bb, W, top, bottom, self.busy and "Đang tải giá vàng…" or "Không tải được. Bấm LÀM MỚI.", 38)
        return
    end
    local landscape = W > H
    local gap = 24
    local lx, ly, lw, lh, rx, ry, rw, rh
    if landscape then
        lw = math.floor((W - 2 * mx - gap) * 0.5)
        lx, ly, lh = mx, top, bottom - top
        rx, ry, rw, rh = mx + lw + gap, top, W - 2 * mx - lw - gap, bottom - top
    else
        lx, ly, lw = mx, top, W - 2 * mx
        lh = math.floor((bottom - top) * 0.45)
        rx, ry, rw = mx, top + lh + gap, W - 2 * mx
        rh = bottom - ry
    end
    bb:paintBorder(lx, ly, lw, lh, 3, BLACK, 26)
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    local gu = math.min(lw / 785, lh / 874)
    local function P(n) return math.floor(n * gu + 0.5) end
    txt(bb, "GIÁ VÀNG HÔM NAY", lx + P(36), ly + P(20), P(32), { bold = true })
    txt(bb, "triệu đồng/lượng", lx + lw - P(36), ly + P(30), P(20), { right = true, color = GRAY5 })
    bb:paintRect(lx + P(36), ly + P(70), lw - P(72), 3, BLACK)
    if #g.rows == 0 then
        txt(bb, "Chưa lấy được bảng giá.", lx + P(36), ly + P(100), P(28), { color = GRAY5, max_width = lw - P(72) })
    else
        local hero, world
        for _, r in ipairs(g.rows) do
            if r.usd then
                world = world or r
            elseif not hero and r.name:find("SJC") then
                hero = r
            end
        end
        if not hero then
            for _, r in ipairs(g.rows) do
                if not r.usd then hero = r; break end
            end
        end
        local cy0 = ly + P(90)
        local chh = P(230)
        local gapc = P(16)
        local cx0 = lx + P(36)
        local cwall = lw - P(72)
        local w1 = world and math.floor(cwall * 0.62) or cwall
        if hero then
            bb:paintRoundedRect(cx0, cy0, w1, chh, BLACK, P(24))
            txt(bb, string.upper(hero.name), cx0 + P(24), cy0 + P(16), P(22), { bold = true, color = WHITE, max_width = w1 - P(48) })
            txt(bb, "BÁN RA", cx0 + P(24), cy0 + P(52), P(20), { color = Blitbuffer.COLOR_GRAY_D })
            txt(bb, hero.sell and fmt(hero.sell, 2) or "—", cx0 + P(24), cy0 + P(70), P(84), { bold = true, color = WHITE })
            txt(bb, "MUA VÀO  " .. (hero.buy and fmt(hero.buy, 2) or "—"), cx0 + P(24), cy0 + chh - P(54), P(30), { bold = true, color = WHITE })
            if hero.buy and hero.sell then
                txt(bb, "chênh " .. fmt(hero.sell - hero.buy, 2), cx0 + w1 - P(24), cy0 + chh - P(46), P(22), { right = true, color = Blitbuffer.COLOR_GRAY_D })
            end
        end
        if world then
            local wx = cx0 + w1 + gapc
            local ww = cwall - w1 - gapc
            bb:paintRoundedRect(wx, cy0, ww, chh, BLACK, P(24))
            bb:paintRoundedRect(wx + 4, cy0 + 4, ww - 8, chh - 8, WHITE, P(20))
            txt(bb, "THẾ GIỚI", wx + P(18), cy0 + P(16), P(22), { bold = true, color = GRAY5 })
            txt(bb, "XAU/USD", wx + P(18), cy0 + P(46), P(26), { bold = true })
            txt(bb, fmt(world.buy, 0), wx + P(18), cy0 + P(96), P(56), { bold = true })
            txt(bb, "USD/ounce", wx + P(18), cy0 + chh - P(46), P(22), { color = GRAY5 })
        end
        -- bảng các loại còn lại
        local yy = cy0 + chh + P(22)
        txt(bb, "MUA", lx + lw - P(36) - P(190), yy, P(20), { right = true, color = GRAY5, bold = true })
        txt(bb, "BÁN", lx + lw - P(36), yy, P(20), { right = true, color = GRAY5, bold = true })
        yy = yy + P(34)
        local colbuy = lx + lw - P(36) - P(190)
        local colsell = lx + lw - P(36)
        local lastsrc = ""
        local stripe = false
        for _, r in ipairs(g.rows) do
            if not r.usd and r ~= hero then
                local need = (r.src ~= lastsrc) and (P(34) + P(46)) or P(46)
                if yy + need > ly + lh - P(14) then break end
                if r.src ~= lastsrc then
                    local lw2 = TextWidget:new{ text = r.src, face = face(P(20)), bold = true, padding = 0 }
                    local tw_ = lw2:getWidth()
                    lw2:free()
                    bb:paintRoundedRect(cx0, yy, tw_ + P(28), P(28), BLACK, P(14))
                    txt(bb, r.src, cx0 + P(14), yy + P(2), P(20), { bold = true, color = WHITE })
                    yy = yy + P(34)
                    lastsrc = r.src
                    stripe = false
                end
                if stripe then bb:paintRect(cx0, yy, cwall, P(44), Blitbuffer.COLOR_GRAY_E) end
                stripe = not stripe
                txt(bb, r.name, cx0 + P(10), yy + P(8), P(24), { max_width = colbuy - P(120) - cx0 })
                txt(bb, r.buy and fmt(r.buy, 2) or "—", colbuy - P(6), yy + P(5), P(28), { right = true, bold = true })
                txt(bb, r.sell and fmt(r.sell, 2) or "—", colsell - P(6), yy + P(5), P(28), { right = true, bold = true })
                yy = yy + P(46)
            end
        end
    end
    bb:paintBorder(rx, ry, rw, rh, 3, BLACK, 26)
    txt(bb, "TIN GIÁ VÀNG", rx + 36, ry + 22, 32, { bold = true })
    bb:paintRect(rx + 36, ry + 72, rw - 72, 3, BLACK)
    if #g.news == 0 then
        txt(bb, "Không tải được tin.", rx + 36, ry + 100, 28, { color = Blitbuffer.COLOR_GRAY_5 })
    else
        local nv = self:navstate("gold")
        if nv.start > #g.news then nv.start = 1; nv.stack = {} end
        nv.total = #g.news
        nv.drawn = headlines(bb, g.news, rx, ry + 64, rw, rh - 64, 1, 28, nv.start, self.hits, function(it) self:openDetail(it) end)
        txt(bb, "Tin " .. nv.start .. "–" .. (nv.start + nv.drawn - 1) .. " / " .. #g.news .. " · bấm để xem tóm tắt",
            rx + rw - 30, ry + rh - 34, 20, { right = true, color = Blitbuffer.COLOR_GRAY_5 })
    end
end

function VNDash:lunar_for(d, m, y)
    local key = y * 10000 + m * 100 + d
    local c = self.cal_cache[key]
    if not c then
        local ld, lm, ly, leap = solar2lunar(d, m, y)
        c = { ld = ld, lm = lm, ly = ly, leap = leap }
        self.cal_cache[key] = c
    end
    return c
end

function VNDash:drawCalendar(bb, W, H)
    local mx = 36
    local top, bottom = area(H)
    local t = os.date("*t")
    local landscape = W > H
    local gap = 24
    local lx, ly, lw, lh, rx, ry, rw, rh
    if landscape then
        lw = math.floor((W - 2 * mx - gap) * 0.46)
        lx, ly, lh = mx, top, bottom - top
        rx, ry, rw, rh = mx + lw + gap, top, W - 2 * mx - lw - gap, bottom - top
    else
        lx, ly, lw = mx, top, W - 2 * mx
        lh = math.floor((bottom - top) * 0.42)
        rx, ry, rw = mx, top + lh + gap, W - 2 * mx
        rh = bottom - ry
    end
    -- ---- khung trái: đồng hồ + từ tiếng Anh
    bb:paintBorder(lx, ly, lw, lh, 3, BLACK, 26)
    local GRAY5 = Blitbuffer.COLOR_GRAY_5
    local u = math.min(lw / 740, lh / 874)
    local function P(n) return math.floor(n * u + 0.5) end
    local x0 = lx + P(40)
    local cwid = lw - P(80)
    txt(bb, os.date("%H:%M"), x0, ly + P(6), P(160), { bold = true })
    txt(bb, WEEKDAYS[t.wday - 1] .. ", " .. t.day .. " tháng " .. t.month .. " năm " .. t.year, x0, ly + P(232), P(34), { bold = true, max_width = cwid })
    local lc = self:lunar_for(t.day, t.month, t.year)
    local lunar_txt = "Âm lịch: " .. lc.ld .. "/" .. lc.lm .. (lc.leap and " (nhuận)" or "") .. " năm " .. canchi_year(lc.ly)
    txt(bb, lunar_txt, x0, ly + P(284), P(28), { max_width = cwid })
    txt(bb, "Ngày " .. canchi_day(t.day, t.month, t.year), x0, ly + P(324), P(24), { color = GRAY5 })
    -- từ tiếng Anh của ngày
    local y = ly + P(372)
    bb:paintRect(x0, y, cwid, 3, BLACK)
    txt(bb, "TỪ TIẾNG ANH CỦA NGÀY", x0, y + P(16), P(22), { bold = true, color = GRAY5 })
    local bw_, bh_ = P(150), P(44)
    local bx_, by_ = x0 + cwid - bw_, y + P(8)
    bb:paintBorder(bx_, by_, bw_, bh_, 2, BLACK, P(14))
    txt(bb, "ĐỔI TỪ", bx_ + math.floor(bw_ / 2), by_ + P(8), P(22), { center = true, bold = true })
    self.hits[#self.hits + 1] = { x = bx_ - 10, y = by_ - 10, w = bw_ + 20, h = bh_ + 20, fn = function() self:next_word() end }
    local w = self:word_today()
    y = y + P(62)
    txt(bb, w[1], x0, y, P(58), { bold = true })
    txt(bb, w[2] .. "   " .. w[3], x0, y + P(72), P(24), { color = GRAY5 })
    local mb = TextBoxWidget:new{ text = w[4], face = face(P(30)), width = cwid, fgcolor = BLACK, bold = true }
    mb:paintTo(bb, x0, y + P(108))
    local mh = mb:getSize().h
    mb:free()
    local eb = TextBoxWidget:new{ text = "“" .. w[5] .. "”", face = face(P(24)), width = cwid, fgcolor = BLACK }
    eb:paintTo(bb, x0, y + P(108) + mh + P(8))
    local eh = eb:getSize().h
    eb:free()
    local vb = TextBoxWidget:new{ text = w[6], face = face(P(22)), width = cwid, fgcolor = GRAY5 }
    vb:paintTo(bb, x0, y + P(108) + mh + P(8) + eh + P(2))
    local vh = vb:getSize().h
    vb:free()
    local ny = y + P(108) + mh + P(8) + eh + P(2) + vh + P(22)
    local limit = ly + lh - P(16)
    -- hôm nay trong lịch sử
    local label, hitems = history_for_today()
    if #hitems > 0 and ny + P(96) < limit then
        bb:paintRect(x0, ny, cwid, 3, BLACK)
        txt(bb, label, x0, ny + P(12), P(22), { bold = true, color = GRAY5 })
        ny = ny + P(46)
        local it = hitems[1]
        local hb = TextBoxWidget:new{ text = it.year .. ": " .. cut(it.text, 150), face = face(P(24)), width = cwid, fgcolor = BLACK }
        local hh = hb:getSize().h
        if ny + hh <= limit then
            hb:paintTo(bb, x0, ny)
            ny = ny + hh + P(16)
        end
        hb:free()
    end
    -- câu hôm nay (nếu còn chỗ)
    if ny + P(90) < limit then
        local q = QUOTES[(tonumber(os.date("%j")) % #QUOTES) + 1]
        local qb = TextBoxWidget:new{ text = "“" .. q .. "”", face = face(P(26)), width = cwid, fgcolor = BLACK, bold = true }
        local qh = qb:getSize().h
        if ny + P(36) + qh <= limit then
            bb:paintRect(x0, ny, cwid, 3, BLACK)
            txt(bb, "CÂU HÔM NAY", x0, ny + P(12), P(22), { bold = true, color = GRAY5 })
            qb:paintTo(bb, x0, ny + P(44))
        end
        qb:free()
    end
    -- ---- khung phải: lịch tháng
    bb:paintBorder(rx, ry, rw, rh, 3, BLACK, 26)
    local ru = math.min(rw / 860, rh / 874)
    local function R(n) return math.floor(n * ru + 0.5) end
    local gx = rx + R(36)
    local gw = rw - R(72)
    txt(bb, "THÁNG " .. t.month .. " · " .. t.year, gx, ry + R(20), R(40), { bold = true })
    local cellw = math.floor(gw / 7)
    local names = { "T2", "T3", "T4", "T5", "T6", "T7", "CN" }
    for i, nm in ipairs(names) do
        txt(bb, nm, gx + (i - 1) * cellw + math.floor(cellw / 2), ry + R(80), R(24), { center = true, bold = true, color = (i == 7) and BLACK or Blitbuffer.COLOR_GRAY_5 })
    end
    bb:paintRect(gx, ry + R(116), gw, 2, BLACK)
    local first = os.time{ year = t.year, month = t.month, day = 1, hour = 12 }
    local startcol = (tonumber(os.date("%w", first)) + 6) % 7
    local ndays = os.date("*t", os.time{ year = t.year, month = t.month + 1, day = 0, hour = 12 }).day
    local cellh = R(84)
    for d = 1, ndays do
        local idx = startcol + d - 1
        local col = idx % 7
        local row = math.floor(idx / 7)
        local cx = gx + col * cellw
        local cy = ry + R(128) + row * cellh
        local lcd = self:lunar_for(d, t.month, t.year)
        local ltxt = (lcd.ld == 1) and (lcd.ld .. "/" .. lcd.lm) or tostring(lcd.ld)
        if d == t.day then
            bb:paintRoundedRect(cx + 4, cy + 2, cellw - 8, cellh - 6, BLACK, R(16))
            txt(bb, tostring(d), cx + math.floor(cellw / 2), cy + R(6), R(34), { center = true, bold = true, color = WHITE })
            txt(bb, ltxt, cx + math.floor(cellw / 2), cy + R(48), R(20), { center = true, color = WHITE })
        else
            txt(bb, tostring(d), cx + math.floor(cellw / 2), cy + R(6), R(34), { center = true, bold = (col == 6) })
            txt(bb, ltxt, cx + math.floor(cellw / 2), cy + R(48), R(20), { center = true, color = Blitbuffer.COLOR_GRAY_6 })
        end
    end
    -- sự kiện sắp tới
    local rows_used = math.ceil((startcol + ndays) / 7)
    local ey = ry + R(128) + rows_used * cellh + R(16)
    if ey < ry + rh - R(100) then
        bb:paintRect(gx, ey - R(8), gw, 3, BLACK)
        txt(bb, "SẮP TỚI", gx, ey, R(24), { bold = true, color = Blitbuffer.COLOR_GRAY_5 })
        ey = ey + R(40)
        local evs = upcoming_events(4, 200)
        for _, e in ipairs(evs) do
            if ey + R(40) > ry + rh - R(16) then break end
            local when = (e.off == 0) and "Hôm nay" or ((e.off == 1) and "Ngày mai" or (e.day .. "/" .. e.month .. "  ·  còn " .. e.off .. " ngày"))
            txt(bb, e.name, gx, ey, R(28), { bold = true, max_width = math.floor(gw * 0.55) })
            txt(bb, when, gx + gw, ey + R(2), R(24), { right = true, color = Blitbuffer.COLOR_GRAY_5 })
            ey = ey + R(46)
        end
    end
end

local DAYNAMES = { [0] = "CN", "T2", "T3", "T4", "T5", "T6", "T7" }

function VNDash:drawWeather(bb, W, H)
    local mx = 36
    local top = 206
    local bottom = H - 30 - 84 - 22 - 20
    local data = self.weather
    if not data then
        local msg = self.busy and "Đang tải thời tiết…" or "Không tải được thời tiết. Bấm LÀM MỚI."
        txt(bb, msg, math.floor(W / 2), math.floor((top + bottom) / 2) - 24, 40, { center = true, bold = true })
        return
    end
    if self.wmode == "hourly" then
        self:drawHourly(bb, W, H, top, bottom, data)
        return
    end
    local cur = data.w.current
    local landscape = W > H
    local gap = 24
    local lx, ly, lw, lh, rx, ry, rw, rh
    if landscape then
        lw = math.floor((W - 2 * mx - gap) * 0.48)
        lx, ly, lh = mx, top, bottom - top
        rx, ry, rw, rh = mx + lw + gap, top, W - 2 * mx - lw - gap, bottom - top
    else
        lx, ly, lw = mx, top, W - 2 * mx
        lh = math.floor((bottom - top) * 0.48)
        rx, ry, rw = mx, top + lh + gap, W - 2 * mx
        rh = bottom - ry
    end
    local u = math.min(lw / 760, lh / 880)
    local function P(n) return math.floor(n * u + 0.5) end
    -- ---- khung trái: hiện tại
    bb:paintBorder(lx, ly, lw, lh, 3, BLACK, P(26))
    local x0 = lx + P(40)
    local xr = lx + lw - P(40)
    txt(bb, tostring(cfg.place or ""), x0, ly + P(22), P(34), { bold = true })
    txt(bb, fmt(cur.temperature_2m, 0) .. "°", x0, ly + P(70), P(170), { bold = true })
    wx_icon(bb, xr - P(90), ly + P(160), P(190), wx_kind(cur.weather_code))
    txt(bb, WX_TEXT[cur.weather_code] or "", x0, ly + P(262), P(40), { bold = true })
    txt(bb, "Cảm giác " .. fmt(cur.apparent_temperature, 0) .. "°  ·  Ẩm " .. fmt(cur.relative_humidity_2m, 0) .. "%  ·  Gió " .. fmt(cur.wind_speed_10m, 0) .. " km/h",
        x0, ly + P(322), P(26), { color = Blitbuffer.COLOR_GRAY_5, max_width = lw - P(80) })
    -- dự báo theo giờ: 6 giờ gần nhất + khả năng mưa
    local hr = data.w.hourly
    local gx, gw = x0, xr - x0
    local sy = ly + P(392)
    bb:paintRect(gx, sy - P(12), gw, 3, BLACK)
    txt(bb, "THEO GIỜ · KHẢ NĂNG MƯA", gx, sy, P(24), { bold = true, color = Blitbuffer.COLOR_GRAY_5 })
    if hr and hr.time and #hr.time > 0 then
        local ncol = 6
        local cw_ = math.floor(gw / ncol)
        for i = 1, ncol do
            if not hr.time[i] then break end
            local hh = tonumber(hr.time[i]:match("T(%d+):")) or 0
            local cxm = gx + (i - 1) * cw_ + math.floor(cw_ / 2)
            local y1 = sy + P(44)
            txt(bb, (i == 1) and "Nay" or (hh .. "h"), cxm, y1, P(28), { center = true, bold = true })
            wx_icon(bb, cxm, y1 + P(80), P(64), wx_kind(hr.weather_code and hr.weather_code[i]))
            txt(bb, fmt(hr.temperature_2m and hr.temperature_2m[i] or 0, 0) .. "°", cxm, y1 + P(124), P(32), { center = true, bold = true })
            local pr = (hr.precipitation_probability and hr.precipitation_probability[i]) or 0
            local barh, bwid = P(80), P(34)
            local by0 = y1 + P(170)
            local bxx = cxm - math.floor(bwid / 2)
            bb:paintBorder(bxx, by0, bwid, barh, 2, BLACK, 0)
            local fillh = math.floor((barh - 4) * pr / 100)
            if fillh > 0 then bb:paintRect(bxx + 2, by0 + barh - 2 - fillh, bwid - 4, fillh, BLACK) end
            txt(bb, fmt(pr, 0) .. "%", cxm, by0 + barh + P(6), P(26), { center = true, bold = true })
        end
        txt(bb, "Thanh đen = khả năng mưa. Bấm THEO GIỜ để xem 24 giờ.", gx, ly + lh - P(30), P(20), { color = Blitbuffer.COLOR_GRAY_5 })
    end
    -- ---- khung phải: không khí + 5 ngày
    bb:paintBorder(rx, ry, rw, rh, 3, BLACK, P(26))
    local ru = math.min(rw / 800, rh / 880)
    local function R(n) return math.floor(n * ru + 0.5) end
    local ax = rx + R(40)
    local ar = rx + rw - R(40)
    txt(bb, "CHẤT LƯỢNG KHÔNG KHÍ", ax, ry + R(22), R(30), { bold = true })
    local air = data.a
    if air and air.us_aqi then
        local v = air.us_aqi
        txt(bb, fmt(v, 0), ax, ry + R(66), R(120), { bold = true })
        txt(bb, "AQI Mỹ", ax + R(220), ry + R(86), R(26), { color = Blitbuffer.COLOR_GRAY_5 })
        txt(bb, aqi_info(v), ax + R(220), ry + R(122), R(34), { bold = true })
        -- thanh thang AQI
        local sx, sy, sw, sh = ax, ry + R(206), ar - ax, R(26)
        local segs = { { 50, Blitbuffer.COLOR_GRAY_E }, { 50, Blitbuffer.COLOR_GRAY_D }, { 50, Blitbuffer.COLOR_GRAY_B },
                       { 50, Blitbuffer.COLOR_GRAY_9 }, { 100, Blitbuffer.COLOR_GRAY_6 }, { 100, BLACK } }
        local tot = 400
        local acc = 0
        for _, sg in ipairs(segs) do
            local x1 = sx + math.floor(sw * acc / tot)
            local x2 = sx + math.floor(sw * (acc + sg[1]) / tot)
            bb:paintRect(x1, sy, x2 - x1, sh, sg[2])
            acc = acc + sg[1]
        end
        bb:paintBorder(sx, sy, sw, sh, 2, BLACK, 0)
        local mxv = math.min(v, tot)
        tri(bb, sx + math.floor(sw * mxv / tot), sy + sh + R(18), R(22), true, BLACK)
        txt(bb, "PM2.5  " .. fmt(air.pm2_5 or 0, 0) .. " µg/m³", ax, ry + R(270), R(28), { bold = true })
        txt(bb, "PM10  " .. fmt(air.pm10 or 0, 0) .. " µg/m³", ar, ry + R(270), R(28), { right = true, bold = true })
    else
        txt(bb, "Chưa có dữ liệu không khí", ax, ry + R(80), R(30), { color = Blitbuffer.COLOR_GRAY_5 })
    end
    -- dự báo 5 ngày
    local dy = ry + R(350)
    bb:paintRect(ax, dy - R(14), ar - ax, 3, BLACK)
    txt(bb, "DỰ BÁO 5 NGÀY", ax, dy, R(26), { bold = true })
    dy = dy + R(50)
    local dl = data.w.daily
    if dl and dl.time then
        local rowh = math.floor((ry + rh - R(20) - dy) / 5)
        for i = 1, math.min(5, #dl.time) do
            local yy, mm, dd = dl.time[i]:match("(%d+)-(%d+)-(%d+)")
            local name = "?"
            if yy then
                local ts = os.time{ year = tonumber(yy), month = tonumber(mm), day = tonumber(dd), hour = 12 }
                name = DAYNAMES[tonumber(os.date("%w", ts))] .. " " .. dd .. "/" .. mm
            end
            if i == 1 then name = "Hôm nay" end
            local ry2 = dy + (i - 1) * rowh
            bb:paintRect(ax, ry2 - R(6), ar - ax, 1, Blitbuffer.COLOR_GRAY_B)
            txt(bb, name, ax, ry2 + R(8), R(30), { bold = (i == 1) })
            wx_icon(bb, ax + R(300), ry2 + math.floor(rowh / 2) - R(4), R(60), wx_kind(dl.weather_code and dl.weather_code[i]))
            local tmax = dl.temperature_2m_max and dl.temperature_2m_max[i] or 0
            local tmin = dl.temperature_2m_min and dl.temperature_2m_min[i] or 0
            txt(bb, fmt(tmin, 0) .. "° / " .. fmt(tmax, 0) .. "°", ax + R(400), ry2 + R(8), R(30), { bold = true })
            local rp = dl.precipitation_probability_max and dl.precipitation_probability_max[i]
            if rp then txt(bb, "Mưa " .. fmt(rp, 0) .. "%", ar, ry2 + R(8), R(26), { right = true, color = Blitbuffer.COLOR_GRAY_5 }) end
        end
    end
end

function VNDash:drawOverview(bb, W, H)
    local mx = 36
    local top = 206
    local bottom = H - 30 - 84 - 22 - 20
    local area_h = bottom - top
    local landscape = W > H
    local gap = 24
    local cw, ch, cols
    if landscape then
        cols = 2
        cw = math.floor((W - 2 * mx - gap) / 2)
        ch = math.floor((area_h - gap) / 2)
    else
        cols = 1
        cw = W - 2 * mx
        ch = math.floor((area_h - 3 * gap) / 4)
    end
    if #self.indices == 0 then
        txt(bb, "Đang tải dữ liệu…", math.floor(W / 2), math.floor(H / 2) - 30, 48, { center = true, bold = true })
        return
    end
    for i, it in ipairs(self.indices) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = mx + col * (cw + gap)
        local cy = top + row * (ch + gap)
        self:drawCard(bb, cx, cy, cw, ch, it)
        local idx = i
        self.hits[#self.hits + 1] = { x = cx, y = cy, w = cw, h = ch, fn = function()
            if it.stock then
                self:lookup(it.sym, "overview")
                return
            end
            self.index_open = idx
            self.mode = "index"
            UIManager:setDirty(self, "full")
        end }
    end
end

function VNDash:drawCard(bb, x, y, w, h, it)
    local u = math.min(w / 776, h / 486)
    local function P(n) return math.floor(n * u + 0.5) end
    local d = it.data
    bb:paintBorder(x, y, w, h, math.max(2, P(3)), BLACK, P(26))
    local x0 = x + P(48)
    local xr = x + w - P(34)
    txt(bb, it.name, x0, y + P(20), P(34), { bold = true })
    if INDEX_TAG[it.name] and not it.stock then
        txt(bb, INDEX_TAG[it.name], x0 + P(250), y + P(30), P(22), { color = Blitbuffer.COLOR_GRAY_5 })
    end
    if not d then
        txt(bb, "Không lấy được dữ liệu", x0, y + P(100), P(34))
        return
    end
    local kind = kind_of(d.change)
    -- thanh nhấn bên trái
    local ax, ay, ah = x + P(16), y + P(34), h - P(68)
    if kind == "up" then
        bb:paintRoundedRect(ax, ay, P(10), ah, BLACK, P(5))
    elseif kind == "down" then
        local yy = ay
        while yy < ay + ah - P(4) do
            bb:paintRect(ax, yy, P(10), P(4), BLACK)
            yy = yy + P(10)
        end
    else
        bb:paintBorder(ax, ay, P(10), ah, 2, Blitbuffer.COLOR_GRAY, P(5))
    end
    -- nhãn
    local pw, ph = P(250), P(64)
    pill(bb, x + w - pw - P(28), y + P(20), pw, ph, kind, P(30))
    -- số điểm
    txt(bb, fmt(d.value, 2), x0, y + P(82), P(96), { bold = true })
    -- thay đổi
    txt(bb, sfmt(d.change, 2), xr, y + P(110), P(44), { right = true, bold = true })
    txt(bb, sfmt(d.pct, 2) .. "%", xr, y + P(164), P(36), { right = true })
    if it.stock then
        local s = it.stock
        local gx, gw = x0, xr - x0
        local gy = y + P(250)
        local GRAY5 = Blitbuffer.COLOR_GRAY_5
        local span = math.max(1e-9, s.ceiling - s.floor)
        local function pos(v) return gx + math.floor(gw * (math.min(math.max(v, s.floor), s.ceiling) - s.floor) / span) end
        bb:paintRect(gx, gy, gw, P(22), Blitbuffer.COLOR_GRAY_E)
        local a, b = pos(s.ref), pos(s.price)
        if b < a then a, b = b, a end
        bb:paintRect(a, gy, math.max(P(4), b - a), P(22), (s.price >= s.ref) and BLACK or Blitbuffer.COLOR_GRAY_6)
        bb:paintBorder(gx, gy, gw, P(22), 2, BLACK, 0)
        bb:paintRect(pos(s.ref) - 1, gy - P(8), 3, P(38), BLACK)
        txt(bb, "Sàn " .. fmt(s.floor / 1000, 2), gx, gy + P(32), P(24), { color = GRAY5 })
        txt(bb, "TC " .. fmt(s.ref / 1000, 2), pos(s.ref), gy + P(32), P(24), { center = true, bold = true })
        txt(bb, "Trần " .. fmt(s.ceiling / 1000, 2), gx + gw, gy + P(32), P(24), { right = true, color = GRAY5 })
        local l1 = "Mở " .. (s.open and fmt(s.open / 1000, 2) or "—") .. "  ·  Cao " .. (s.high and fmt(s.high / 1000, 2) or "—") .. "  ·  Thấp " .. (s.low and fmt(s.low / 1000, 2) or "—")
        txt(bb, l1, x0, y + P(352), P(26), { bold = true, max_width = gw })
        txt(bb, "KL " .. fmt(s.vol / 1e6, 2) .. " tr cp  ·  GTGD " .. fmt(s.val / 1e9, 0) .. " tỷ", x0, y + P(396), P(26), { color = GRAY5, max_width = gw })
        txt(bb, "Bấm để xem chi tiết và tin", x0, y + P(438), P(22), { color = GRAY5 })
        return
    end
    -- biểu đồ
    local gx, gy, gw, gh = x0, y + P(236), xr - x0, P(120)
    local hist = d.hist
    if #hist >= 2 then
        local lo, hi = d.prev, d.prev
        for _, v in ipairs(hist) do
            if v < lo then lo = v end
            if v > hi then hi = v end
        end
        if hi == lo then hi = lo + 1 end
        local base = P(10)
        local n = #hist
        local function hh(v) return base + (v - lo) / (hi - lo) * (gh - base) end
        for i, v in ipairs(hist) do
            local bx = gx + math.floor((i - 1) * gw / n)
            local bw = math.max(2, math.floor(gw / n) - math.max(2, P(3)))
            local bh = math.floor(hh(v))
            local col = (v >= d.prev) and BLACK or Blitbuffer.COLOR_GRAY_9
            bb:paintRect(bx, gy + gh - bh, bw, bh, col)
        end
        -- đường tham chiếu
        local ry = gy + gh - math.floor(hh(d.prev))
        local dx = gx
        while dx < gx + gw do
            bb:paintRect(dx, ry, P(8), 2, BLACK)
            dx = dx + P(16)
        end
    end
    bb:paintRect(gx, gy + gh, gw, 2, BLACK)
    -- thanh tăng/giảm
    local by, bh = y + P(376), P(22)
    local total = d.adv + d.dec + d.unch
    if total > 0 then
        local wa = math.floor(gw * d.adv / total)
        local wu = math.floor(gw * d.unch / total)
        local wd = gw - wa - wu
        bb:paintRect(gx, by, gw, bh, Blitbuffer.COLOR_GRAY_E)
        bb:paintRect(gx, by, wa, bh, BLACK)
        bb:paintRect(gx + wa, by, wu, bh, Blitbuffer.COLOR_GRAY_B)
        bb:paintBorder(gx, by, gw, bh, 2, BLACK, 0)
    end
    txt(bb, "Tăng " .. d.adv, gx, y + P(402), P(26), { bold = true })
    txt(bb, "Đứng " .. d.unch, gx + math.floor(gw / 2), y + P(402), P(26), { center = true })
    txt(bb, "Giảm " .. d.dec, gx + gw, y + P(402), P(26), { right = true, bold = true })
    -- chi tiết
    local line = "GTGD " .. fmt(d.val, 0) .. " tỷ"
    if it.foreign and d.fbuy and d.fsell then
        local net = (d.fbuy - d.fsell) / 1e6
        local lb = (net < 0) and "bán ròng" or "mua ròng"
        line = line .. "  ·  Khối ngoại " .. lb .. " " .. fmt(math.abs(net), 1) .. " tr cp"
    end
    txt(bb, line, x0, y + P(438), P(26), { color = Blitbuffer.COLOR_GRAY_5, max_width = gw })
end

function VNDash:drawStock(bb, W, H)
    local mx = 36
    local top = 206
    local bottom = H - 30 - 84 - 22 - 20
    local s = self.stock
    if not s or s.error then
        txt(bb, (s and s.error) or "Chưa có dữ liệu", math.floor(W / 2), math.floor(H / 2) - 30, 44, { center = true, bold = true })
        return
    end
    local d = s.d
    local landscape = W > H
    local gap = 24
    local lx, ly, lw, lh, rx, ry, rw, rh
    if landscape then
        lw = math.floor((W - 2 * mx - gap) * 0.50)
        lx, ly, lh = mx, top, bottom - top
        rx, ry, rw, rh = mx + lw + gap, top, W - 2 * mx - lw - gap, bottom - top
    else
        lx, ly, lw = mx, top, W - 2 * mx
        lh = math.floor((bottom - top) * 0.58)
        rx, ry, rw = mx, top + lh + gap, W - 2 * mx
        rh = bottom - ry
    end
    local u = math.min(lw / 780, lh / 940)
    local function P(n) return math.floor(n * u + 0.5) end
    -- ---- khung trái (cùng kiểu thẻ chỉ số)
    bb:paintBorder(lx, ly, lw, lh, 3, BLACK, P(26))
    local x0 = lx + P(48)
    local xr = lx + lw - P(34)
    local price = d.matchedPrice
    if not price or price == 0 then price = d.priceChange and (d.refPrice + d.priceChange) or d.refPrice end
    local ref = d.refPrice or price
    local change = d.priceChange or (price - ref)
    local pct = d.priceChangePercent or 0
    local kind = kind_of(change)
    local ax, ay, ah = lx + P(16), ly + P(34), P(250)
    if kind == "up" then
        bb:paintRoundedRect(ax, ay, P(10), ah, BLACK, P(5))
    elseif kind == "down" then
        local yy = ay
        while yy < ay + ah - P(4) do
            bb:paintRect(ax, yy, P(10), P(4), BLACK)
            yy = yy + P(10)
        end
    else
        bb:paintBorder(ax, ay, P(10), ah, 2, Blitbuffer.COLOR_GRAY, P(5))
    end
    txt(bb, d.stockSymbol, x0, ly + P(14), P(72), { bold = true })
    local exch = tostring(d.exchange or ""):upper()
    local name = d.companyNameVi or d.clientName or ""
    txt(bb, exch .. "  ·  " .. name, x0, ly + P(104), P(24), { max_width = lw - P(90), color = Blitbuffer.COLOR_GRAY_5 })
    local pw, ph = P(250), P(64)
    pill(bb, xr - pw, ly + P(20), pw, ph, kind, P(30))
    txt(bb, fmt(price / 1000, 2), x0, ly + P(150), P(104), { bold = true })
    txt(bb, sfmt(change / 1000, 2), xr, ly + P(160), P(44), { right = true, bold = true })
    txt(bb, sfmt(pct, 2) .. "%", xr, ly + P(214), P(36), { right = true })
    -- thanh sàn - tham chiếu - trần
    local fl, ce = d.floor or ref, d.ceiling or ref
    local gx, gy, gw = x0, ly + P(350), xr - x0
    bb:paintRect(gx, gy, gw, P(14), Blitbuffer.COLOR_GRAY_D)
    local function pos(v)
        if ce == fl then return gx end
        local t = (v - fl) / (ce - fl)
        if t < 0 then t = 0 elseif t > 1 then t = 1 end
        return gx + math.floor(t * gw)
    end
    bb:paintRect(pos(ref) - 2, gy - P(10), 4, P(34), BLACK)
    bb:paintRect(gx, gy, math.max(1, pos(price) - gx), P(14), BLACK)
    tri(bb, pos(price), gy + P(40), P(22), true, BLACK)
    txt(bb, "Sàn " .. fmt(fl / 1000, 2), gx, gy + P(60), P(24))
    txt(bb, "TC " .. fmt(ref / 1000, 2), pos(ref), gy + P(60), P(24), { center = true, bold = true })
    txt(bb, "Trần " .. fmt(ce / 1000, 2), gx + gw, gy + P(60), P(24), { right = true })
    -- bảng chỉ số
    local rows = {
        { "Mở cửa", fmt((d.openPrice or 0) / 1000, 2), "Cao nhất", fmt((d.highest or 0) / 1000, 2) },
        { "Thấp nhất", fmt((d.lowest or 0) / 1000, 2), "Trung bình", fmt((d.avgPrice or 0) / 1000, 2) },
        { "KL khớp", fmt((d.nmTotalTradedQty or d.stockVol or 0) / 1000, 0) .. " nghìn", "GTGD", fmt((d.nmTotalTradedValue or 0) / 1e9, 1) .. " tỷ" },
        { "NN mua", fmt((d.buyForeignQtty or 0) / 1000, 0) .. " nghìn", "NN bán", fmt((d.sellForeignQtty or 0) / 1000, 0) .. " nghìn" },
    }
    local ty = gy + P(112)
    local colw = math.floor(gw / 2)
    local rh2 = P(84)
    for _, r in ipairs(rows) do
        bb:paintRect(gx, ty - P(6), gw, 1, Blitbuffer.COLOR_GRAY_B)
        txt(bb, r[1], gx, ty, P(22), { color = Blitbuffer.COLOR_GRAY_5 })
        txt(bb, r[2], gx, ty + P(26), P(34), { bold = true })
        txt(bb, r[3], gx + colw + P(16), ty, P(22), { color = Blitbuffer.COLOR_GRAY_5 })
        txt(bb, r[4], gx + colw + P(16), ty + P(26), P(34), { bold = true })
        ty = ty + rh2
    end
    -- ---- khung phải: tin tức
    bb:paintBorder(rx, ry, rw, rh, 3, BLACK, 26)
    txt(bb, "TIN MỚI NHẤT", rx + 36, ry + 22, 32, { bold = true })
    bb:paintRect(rx + 36, ry + 72, rw - 72, 3, BLACK)
    local ny = ry + 92
    local news = s.news or {}
    if #news == 0 then
        txt(bb, "Không có tin trong 7 ngày qua", rx + 36, ny, 28, { color = Blitbuffer.COLOR_GRAY_5 })
    end
    for _, n in ipairs(news) do
        local tb = TextBoxWidget:new{
            text = n.title,
            face = face(30),
            width = rw - 72,
            fgcolor = BLACK,
        }
        local th = tb:getSize().h
        if ny + th + 56 > ry + rh - 16 then
            tb:free()
            break
        end
        local item_top = ny
        local item = n
        self.hits[#self.hits + 1] = { x = rx + 30, y = item_top - 6, w = rw - 60, h = th + 66, fn = function() self:openDetail(item) end }
        tb:paintTo(bb, rx + 36, ny)
        tb:free()
        ny = ny + th + 6
        local meta = n.source
        if n.when ~= "" then meta = (meta ~= "" and (meta .. "  ·  ") or "") .. n.when end
        txt(bb, meta, rx + 36, ny, 22, { color = Blitbuffer.COLOR_GRAY_5 })
        ny = ny + 34
        bb:paintRect(rx + 36, ny, rw - 72, 1, Blitbuffer.COLOR_GRAY_B)
        ny = ny + 16
    end
end

function VNDash:start()
    os.execute("mkdir -p /mnt/us/vn_dash")
    os.execute("lipc-set-prop com.lab126.powerd preventScreenSaver 1 >/dev/null 2>&1")
    self.old_rotation = Screen:getRotationMode()
    if cfg.rotation ~= nil and cfg.rotation ~= self.old_rotation then
        Screen:setRotationMode(cfg.rotation)
    end
    self.dimen = Geom:new{ x = 0, y = 0, w = Screen:getWidth(), h = Screen:getHeight() }
    self.ges_events.Tap = { GestureRange:new{ ges = "tap", range = self.dimen } }
    UIManager:show(self, "full")
    UIManager:scheduleIn(0.5, function() self:refresh(true) end)
end

-- ===== plugin =====
local VNMarket = WidgetContainer:extend{
    name = "vnmarket",
    is_doc_only = false,
}

function VNMarket:onDispatcherRegisterActions()
    local ok, Dispatcher = pcall(require, "dispatcher")
    if ok and Dispatcher then
        Dispatcher:registerAction("vnmarket_dash", {
            category = "none",
            event = "ShowVNDash",
            title = "Bảng điện tối thượng",
            general = true,
        })
    end
end

function VNMarket:onShowVNDash()
    local w = VNDash:new{}
    w:start()
    return true
end

function VNMarket:init()
    pcall(function() self:onDispatcherRegisterActions() end)
    self.ui.menu:registerToMainMenu(self)
    pcall(log, "autostart init: auto=" .. tostring(cfg.autostart) .. " name=" .. tostring(self.ui and self.ui.name) .. " doc=" .. tostring(self.ui and self.ui.document ~= nil) .. " done=" .. tostring(_G.__vnm_autostarted))
    if cfg.autostart and not _G.__vnm_autostarted and self.ui and not self.ui.document then
        _G.__vnm_autostarted = true
        UIManager:scheduleIn(2, function()
            pcall(function() self:onShowVNDash() end)
        end)
    end
end

function VNMarket:addToMainMenu(menu_items)
    menu_items.vnmarket = {
        text = "Bảng điện tối thượng",
        sorting_hint = "tools",
        callback = function()
            self:onShowVNDash()
        end,
    }
    menu_items.vnmarket_auto = {
        text = "Tự mở bảng điện khi bật KOReader",
        sorting_hint = "tools",
        checked_func = function() return cfg.autostart end,
        callback = function()
            cfg.autostart = not cfg.autostart
            save_user()
        end,
    }
end

return VNMarket
