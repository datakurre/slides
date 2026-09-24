-- Pandoc Lua filter for presentation slides (Beamer PDF & Marp HTML)
--
-- Features:
-- 1. BPMN 2.0 diagrams (.bpmn, .xml, ```bpmn code blocks) rendered to SVG/PDF via bpmn-to-image
-- 2. SVG images converted to PDF via rsvg-convert for pdflatex
-- 3. BPMN animations rendered as WebP in Marp and a middle frame in Beamer PDF
-- 4. MP4/WebM videos: native HTML5 <video> in Marp, ffmpeg poster snapshot in Beamer PDF
-- 5. Standout slides and presentation helpers across both backends

local is_latex = FORMAT:match('latex') or FORMAT:match('beamer')
local is_marp = FORMAT:match('markdown') or FORMAT:match('gfm')

local tmpdir = os.getenv('SLIDES_CACHE_DIR') or os.getenv('SLIDES_TMPDIR') or os.getenv('TMPDIR') or '/tmp'

local is_fast = os.getenv('SLIDES_FAST') == '1' or os.getenv('SLIDES_FAST') == 'true'
local is_quick = os.getenv('SLIDES_QUICK') == '1' or os.getenv('SLIDES_QUICK') == 'true'
local max_duration_ms = os.getenv('SLIDES_MAX_DURATION_MS') or '60000'
-- When set, ignore cached renders and regenerate every diagram/animation,
-- overwriting whatever was cached under the same content-derived hash.
local no_cache = os.getenv('SLIDES_NO_CACHE') == '1' or os.getenv('SLIDES_NO_CACHE') == 'true'

local function file_exists(name)
  local f = io.open(name, 'r')
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local function resolve_path(src)
  if not src or src == '' or src:match('^https?://') or src:match('^data:') then
    return src
  end
  if file_exists(src) then
    return src
  end
  if PANDOC_STATE and PANDOC_STATE.input_files and #PANDOC_STATE.input_files > 0 then
    local doc_path = PANDOC_STATE.input_files[1]
    local doc_dir = pandoc.path.directory(doc_path)
    if doc_dir and doc_dir ~= '' and doc_dir ~= '.' then
      local candidate1 = pandoc.path.join({doc_dir, src})
      if file_exists(candidate1) then
        return candidate1
      end
      local candidate2 = pandoc.path.join({doc_dir, '..', src})
      if file_exists(candidate2) then
        return candidate2
      end
      local candidate3 = pandoc.path.join({doc_dir, '..', '..', src})
      if file_exists(candidate3) then
        return candidate3
      end
    end
  end
  return nil
end

local bs = { [0] =
   "A","B","C","D","E","F","G","H","I","J","K","L","M","N","O","P",
   "Q","R","S","T","U","V","W","X","Y","Z","a","b","c","d","e","f",
   "g","h","i","j","k","l","m","n","o","p","q","r","s","t","u","v",
   "w","x","y","z","0","1","2","3","4","5","6","7","8","9","+","/"
}

local function to_base64(data)
  if not data or #data == 0 then return '' end
  local t, n = {}, 1
  local len = #data
  local rem = len % 3
  local dlen = len - rem
  for i = 1, dlen, 3 do
    local b1, b2, b3 = data:byte(i, i + 2)
    local n1 = (b1 >> 2) & 63
    local n2 = (((b1 & 3) << 4) | ((b2 >> 4) & 15)) & 63
    local n3 = (((b2 & 15) << 2) | ((b3 >> 6) & 3)) & 63
    local n4 = b3 & 63
    t[n] = bs[n1] .. bs[n2] .. bs[n3] .. bs[n4]
    n = n + 1
  end
  if rem == 1 then
    local b1 = data:byte(dlen + 1)
    t[n] = bs[(b1 >> 2) & 63] .. bs[((b1 & 3) << 4) & 63] .. "=="
  elseif rem == 2 then
    local b1, b2 = data:byte(dlen + 1, dlen + 2)
    t[n] = bs[(b1 >> 2) & 63] .. bs[(((b1 & 3) << 4) | ((b2 >> 4) & 15)) & 63] .. bs[((b2 & 15) << 2) & 63] .. "="
  end
  return table.concat(t)
end

local function get_mime_type(ext)
  local mimes = {
    png = 'image/png',
    jpg = 'image/jpeg',
    jpeg = 'image/jpeg',
    gif = 'image/gif',
    svg = 'image/svg+xml',
    webp = 'image/webp',
    bmp = 'image/bmp',
    ico = 'image/x-icon',
    mp4 = 'video/mp4',
    webm = 'video/webm',
    mov = 'video/quicktime',
  }
  return mimes[ext] or 'application/octet-stream'
end

local function read_file(path)
  local f = io.open(path, 'rb')
  if not f then return nil end
  local content = f:read('*all')
  f:close()
  return content
end

local function file_to_data_uri(file_path, mime)
  local content = read_file(file_path)
  if not content then return nil end
  return 'data:' .. mime .. ';base64,' .. to_base64(content)
end

local function get_hash(text)
  return pandoc.utils.sha1(text)
end

-- Hash the contents so a changed source at the same path invalidates its cache.
local function get_file_hash(path)
  return get_hash(read_file(path) or path)
end

-- BPMN element types that can be rendered as a standalone symbol without
-- requiring connections or references to other process elements.
local bpmn_symbol_types = {
  task = true,
  userTask = true,
  serviceTask = true,
  manualTask = true,
  scriptTask = true,
  sendTask = true,
  receiveTask = true,
  businessRuleTask = true,
  callActivity = true,
  subProcess = true,
  startEvent = true,
  endEvent = true,
  intermediateCatchEvent = true,
  intermediateThrowEvent = true,
  timerBoundaryEvent = true,
  nonInterruptingTimerBoundaryEvent = true,
  errorBoundaryEvent = true,
  messageBoundaryEvent = true,
  signalBoundaryEvent = true,
  exclusiveGateway = true,
  parallelGateway = true,
  inclusiveGateway = true,
  complexGateway = true,
  eventBasedGateway = true,
}

local function xml_escape(value)
  return tostring(value or '')
    :gsub('&', '&amp;')
    :gsub('<', '&lt;')
    :gsub('>', '&gt;')
    :gsub('"', '&quot;')
    :gsub("'", '&apos;')
end

local function bpmn_symbol_xml(symbol_type, label)
  local sizes = {
    startEvent = { width = 36, height = 36 },
    endEvent = { width = 36, height = 36 },
    intermediateCatchEvent = { width = 36, height = 36 },
    intermediateThrowEvent = { width = 36, height = 36 },
    timerBoundaryEvent = { width = 36, height = 36 },
    nonInterruptingTimerBoundaryEvent = { width = 36, height = 36 },
    errorBoundaryEvent = { width = 36, height = 36 },
    messageBoundaryEvent = { width = 36, height = 36 },
    signalBoundaryEvent = { width = 36, height = 36 },
    exclusiveGateway = { width = 50, height = 50 },
    parallelGateway = { width = 50, height = 50 },
    inclusiveGateway = { width = 50, height = 50 },
    complexGateway = { width = 50, height = 50 },
    eventBasedGateway = { width = 50, height = 50 },
    subProcess = { width = 140, height = 100 },
    callActivity = { width = 100, height = 80 },
  }
  local size = sizes[symbol_type] or { width = 100, height = 80 }
  local name = label and tostring(label) or ''
  local name_attribute = name ~= '' and (' name="' .. xml_escape(name) .. '"') or ''
  local element_type = symbol_type
  local event_definition = ''
  if symbol_type == 'timerBoundaryEvent' then
    element_type = 'intermediateCatchEvent'
    event_definition = '<bpmn:timerEventDefinition />'
  elseif symbol_type == 'nonInterruptingTimerBoundaryEvent' then
    element_type = 'intermediateCatchEvent'
    event_definition = '<bpmn:timerEventDefinition />'
  elseif symbol_type == 'errorBoundaryEvent' then
    element_type = 'intermediateCatchEvent'
    event_definition = '<bpmn:errorEventDefinition />'
  elseif symbol_type == 'messageBoundaryEvent' then
    element_type = 'intermediateCatchEvent'
    event_definition = '<bpmn:messageEventDefinition />'
  elseif symbol_type == 'signalBoundaryEvent' then
    element_type = 'intermediateCatchEvent'
    event_definition = '<bpmn:signalEventDefinition />'
  end

  return ([=[<?xml version="1.0" encoding="UTF-8"?>
<bpmn:definitions xmlns:bpmn="http://www.omg.org/spec/BPMN/20100524/MODEL"
                  xmlns:bpmndi="http://www.omg.org/spec/BPMN/20100524/DI"
                  xmlns:dc="http://www.omg.org/spec/DD/20100524/DC"
                  xmlns:di="http://www.omg.org/spec/DD/20100524/DI"
                  id="Definitions_symbol" targetNamespace="http://bpmn.io/schema/bpmn">
  <bpmn:process id="Process_symbol" isExecutable="false">
    <bpmn:%s id="Symbol_1"%s>%s</bpmn:%s>
  </bpmn:process>
  <bpmndi:BPMNDiagram id="BPMNDiagram_symbol">
    <bpmndi:BPMNPlane id="BPMNPlane_symbol" bpmnElement="Process_symbol">
      <bpmndi:BPMNShape id="Symbol_1_di" bpmnElement="Symbol_1">
        <dc:Bounds x="0" y="0" width="%d" height="%d" />
      </bpmndi:BPMNShape>
    </bpmndi:BPMNPlane>
  </bpmndi:BPMNDiagram>
</bpmn:definitions>
]=]):format(element_type, name_attribute, event_definition, element_type, size.width, size.height)
end

local function dashed_boundary_symbol(svg_path)
  local svg = read_file(svg_path)
  if not svg then return svg_path end
  local dashed = svg:gsub('(<circle[^>]-style=")', '%1stroke-dasharray: 4 3; ', 1)
  if dashed == svg then return svg_path end

  local output = pandoc.path.join({tmpdir, 'symbol-dashed-' .. get_hash(svg) .. '.svg'})
  if no_cache or not file_exists(output) then
    local f = io.open(output, 'w')
    if not f then return svg_path end
    f:write(dashed)
    f:close()
  end
  return output
end

local function bpmn_symbol_to_file(symbol_type, label)
  if not bpmn_symbol_types[symbol_type] then
    error(('slides: unsupported BPMN symbol type: %s\n'):format(tostring(symbol_type)))
  end

  local xml = bpmn_symbol_xml(symbol_type, label)
  local hash = get_hash(xml)
  local bpmn_path = pandoc.path.join({tmpdir, 'symbol-' .. hash .. '.bpmn'})
  if no_cache or not file_exists(bpmn_path) then
    local f = io.open(bpmn_path, 'w')
    if not f then
      error(('slides: could not write generated BPMN symbol: %s\n'):format(bpmn_path))
    end
    f:write(xml)
    f:close()
  end
  return bpmn_path
end

local function border_width(value)
  if not value then return nil end
  local text = tostring(value):lower():gsub('^%s+', ''):gsub('%s+$', '')
  if text == 'thin' or text == 'medium' or text == 'thick' then
    return text
  end
  if text == '0' then
    return text
  end
  local units = {
    px = true, pt = true, mm = true, cm = true, in_ = true,
    bp = true, pc = true, em = true, ex = true, rem = true, ['%'] = true,
  }
  local number, unit = text:match('^(%d*%.?%d+)([a-z%%]+)$')
  if number and units[unit == 'in' and 'in_' or unit] then
    return text
  end
  return nil
end

local function latex_border_width(value)
  local text = border_width(value)
  if not text then return nil end
  if text == 'thin' then return '0.4pt' end
  if text == 'medium' then return '0.8pt' end
  if text == 'thick' then return '1.2pt' end

  local number, unit = text:match('^(%d*%.?%d+)([a-z%%]*)$')
  if not number then return nil end
  if unit == '' then return number .. 'pt' end
  if unit == 'px' then
    return ('%.4fpt'):format(tonumber(number) * 0.75)
  end
  if unit == '%' or unit == 'rem' then return nil end
  return number .. unit
end

local function latex_image(img)
  if not is_latex then return img end
  local border = latex_border_width(img.attributes and img.attributes.border)
  if not border then return img end
  local src = tostring(img.src):gsub('([{}])', '\\%1')
  return pandoc.RawInline('latex', '\\borderedimage{' .. border .. '}{' .. src .. '}')
end

local function latex_inline_symbol(src, attrs)
  local safe_src = tostring(src):gsub('([{}])', '\\%1')
  local options = {}
  if attrs then
    if attrs.width then table.insert(options, 'width=' .. attrs.width) end
    if attrs.height then table.insert(options, 'height=' .. attrs.height) end
  end

  local include = '\\includegraphics'
  if #options > 0 then
    include = include .. '[' .. table.concat(options, ',') .. ']'
  end
  include = include .. '{' .. safe_src .. '}'

  local border = latex_border_width(attrs and attrs.border)
  if border then
    include = '\\begingroup\\setlength{\\fboxrule}{' .. border .. '}\\setlength{\\fboxsep}{0pt}\\fbox{' .. include .. '}\\endgroup'
  end

  -- Match CSS vertical-align: middle behavior for inline symbol images.
  return pandoc.RawInline('latex', '\\raisebox{-0.3\\height}{' .. include .. '}')
end

local function html_image(src, attributes, image_classes)
  local safe_src = tostring(src):gsub('&', '&amp;'):gsub('"', '&quot;')
  local styles = {}
  local classes = {}
  if attributes then
    if attributes.width then table.insert(styles, 'width:' .. attributes.width) end
    if attributes.height then table.insert(styles, 'height:' .. attributes.height) end
    local border = border_width(attributes.border)
    if border then table.insert(styles, 'border:' .. border .. ' solid currentColor') end
    if attributes.align then
      local align = attributes.align:lower()
      if align == 'left' or align == 'center' or align == 'right' then
        table.insert(classes, 'align-' .. align)
      end
    end
  end
  if image_classes then
    for _, class in ipairs(image_classes) do
      table.insert(classes, class)
    end
  end
  local style = #styles > 0 and ' style="' .. table.concat(styles, ';') .. '"' or ''
  local class = #classes > 0 and ' class="' .. table.concat(classes, ' ') .. '"' or ''
  return pandoc.RawInline('html', '<img src="' .. safe_src .. '" alt=""' .. class .. style .. '>')
end

-- Convert BPMN XML to SVG using bpmn-to-image
local function bpmn_to_svg(bpmn_path, bg_color)
  local hash = get_hash(get_file_hash(bpmn_path) .. (bg_color or ''))
  local svg_path = pandoc.path.join({tmpdir, 'bpmn-' .. hash .. '.svg'})

  if no_cache or not file_exists(svg_path) then
    local args = {}
    if bg_color then
      table.insert(args, '--background')
      table.insert(args, bg_color)
    end
    table.insert(args, bpmn_path)
    table.insert(args, svg_path)
    
    local ok, err = pcall(pandoc.pipe, 'bpmn-to-image', args, '')
    if not ok then
      error(('slides: bpmn-to-image failed for %s:\n%s\n'):format(bpmn_path, tostring(err)))
    end
  end

  local svg = read_file(svg_path)
  if svg then
    local normalized = svg:gsub(
      'font%-family:%s*IBMPlexSans[^;]*;',
      "font-family: 'Liberation Sans', 'Fira Sans', 'DejaVu Sans', Arial, sans-serif;"
    )
    if normalized ~= svg then
      local f = io.open(svg_path, 'wb')
      if not f then
        error(('slides: could not rewrite BPMN SVG font stack: %s\n'):format(svg_path))
      end
      f:write(normalized)
      f:close()
    end
  end

  return svg_path
end

-- Generate BPMN DI for temporary files created from inline BPMN blocks.
local function bpmn_autolayout(bpmn_path)
  local ok, err = pcall(pandoc.pipe, 'bpmn-autolayout', {bpmn_path}, '')
  if not ok then
    error(('slides: bpmn-autolayout failed for %s:\n%s\n'):format(bpmn_path, tostring(err)))
  end
end

-- Convert SVG to PDF using rsvg-convert
local function svg_to_pdf(svg_path)
  local hash = get_hash(svg_path)
  local pdf_path = pandoc.path.join({tmpdir, 'svg-' .. hash .. '.pdf'})

  if no_cache or not file_exists(pdf_path) then
    local ok, err = pcall(pandoc.pipe, 'rsvg-convert', {'--format=pdf', '--output=' .. pdf_path, svg_path}, '')
    if not ok then
      error(('slides: rsvg-convert failed for %s:\n%s\n'):format(svg_path, tostring(err)))
    end
  end
  return pdf_path
end

local function render_bpmn_symbol(symbol_type, label, background)
  local bpmn_path = bpmn_symbol_to_file(symbol_type, label)
  local svg_path = bpmn_to_svg(bpmn_path, background)
  if symbol_type == 'nonInterruptingTimerBoundaryEvent' then
    svg_path = dashed_boundary_symbol(svg_path)
  end
  if is_latex then
    return svg_to_pdf(svg_path)
  end
  return svg_path
end

local function symbol_label(value)
  if value == nil then return nil end
  local text = pandoc.utils.stringify(value)
  return text ~= '' and text or nil
end

local function symbol_attributes(attributes)
  local result = {}
  if attributes then
    for _, key in ipairs({'width', 'height', 'align', 'border'}) do
      if attributes[key] then result[key] = attributes[key] end
    end
  end
  return result
end

local function bpmn_symbol_label(symbol_type, label)
  if symbol_type:match('Event$') or symbol_type:match('Gateway$') then
    return nil
  end
  return label
end

local function apply_default_symbol_size(attrs)
  -- Keep symbols inline with surrounding text unless the author explicitly
  -- provides dimensions.
  if attrs.width or attrs.height then
    return attrs
  end
  attrs.height = '1.2em'
  return attrs
end

local function symbol_inline(symbol_type, label, attributes)
  local path = render_bpmn_symbol(symbol_type, bpmn_symbol_label(symbol_type, label), attributes and attributes.background)
  local attrs = apply_default_symbol_size(symbol_attributes(attributes))

  if is_latex then
    return latex_inline_symbol(path, attrs)
  end

  local data_uri = file_to_data_uri(path, 'image/svg+xml')
  local image = pandoc.Image(pandoc.List(), data_uri or path)
  image.attr = pandoc.Attr('', {'bpmn-symbol'}, attrs)
  return latex_image(image)
end

-- Convert BPMN to animated WebP for browser slides.
local function bpmn_to_webp(bpmn_path, scenario_path, bg_color)
  local quality = is_quick and 'quick' or 'smooth'
  local hash = get_hash(get_file_hash(bpmn_path) .. (scenario_path and get_file_hash(scenario_path) or '') .. (bg_color or '') .. 'webp-' .. quality .. '-max-' .. max_duration_ms)
  local out_path = pandoc.path.join({tmpdir, 'bpmn-anim-' .. hash .. '.webp'})

  if no_cache or not file_exists(out_path) then
    local args = {'--format', 'webp'}
    if is_quick then
      table.insert(args, '--fps')
      table.insert(args, '12')
    else
      table.insert(args, '--smooth')
    end
    table.insert(args, '--max-duration')
    table.insert(args, max_duration_ms)
    if bg_color then
      table.insert(args, '--background')
      table.insert(args, bg_color)
    end
    if scenario_path and file_exists(scenario_path) then
      table.insert(args, '--scenario')
      table.insert(args, scenario_path)
    end
    table.insert(args, bpmn_path)
    table.insert(args, out_path)
    
    local ok, err = pcall(pandoc.pipe, 'bpmn-to-image', args, '')
    if not ok then
      error(('slides: bpmn-to-image WebP animation failed for %s:\n%s\n'):format(bpmn_path, tostring(err)))
    end
  end
  return out_path
end

-- Live, interactive BPMN simulator embed (see bpmn-to-image's --format html).
-- Unlike the animated/static renders above, this needs no headless
-- rendering at build time — it's just packaging the diagram XML with a
-- bundled bpmn-js viewer that runs the token simulation live, in the
-- reader's own browser.
local simulator_assets_emitted = false
local simulator_counter = 0

local function bpmn_simulator_id(bpmn_path)
  simulator_counter = simulator_counter + 1
  return 'bpmn-sim-' .. get_file_hash(bpmn_path):sub(1, 12) .. '-' .. simulator_counter
end

local function bpmn_to_simulator_html(bpmn_path, id, opts)
  opts = opts or {}
  local args = {'--format', 'html', '--id', id}
  if opts.background then
    table.insert(args, '--background')
    table.insert(args, opts.background)
  end
  if opts.width then
    table.insert(args, '--width')
    table.insert(args, opts.width)
  end
  if opts.height then
    table.insert(args, '--height')
    table.insert(args, opts.height)
  end
  if opts.align then
    table.insert(args, '--align')
    table.insert(args, opts.align)
  end
  if not opts.include_assets then
    table.insert(args, '--no-assets')
  end
  table.insert(args, bpmn_path)
  table.insert(args, '-')

  local ok, result = pcall(pandoc.pipe, 'bpmn-to-image', args, '')
  if not ok then
    error(('slides: bpmn-to-image --format html failed for %s:\n%s\n'):format(bpmn_path, tostring(result)))
  end
  if opts.include_assets then
    result = result .. [=[<script>(function(){function refit(){document.querySelectorAll('.bpmn-simulator').forEach(function(c){if(!c.getClientRects().length)return;var b=c.querySelector('.bpmn-simulator-fit');if(b)b.click()})}function schedule(){requestAnimationFrame(function(){refit();setTimeout(refit,100);setTimeout(refit,500)})}window.addEventListener('load',schedule);window.addEventListener('pageshow',schedule);window.addEventListener('hashchange',schedule);document.addEventListener('visibilitychange',function(){if(!document.hidden)schedule()})}());</script>]=]
  end
  return result
end

-- Extract poster frame from video using ffmpeg
local function extract_video_poster(video_path)
  local hash = get_hash(video_path)
  local poster_path = pandoc.path.join({tmpdir, 'video-poster-' .. hash .. '.png'})

  if no_cache or not file_exists(poster_path) then
    local ok, _ = pcall(pandoc.pipe, 'ffmpeg', {
      '-y', '-ss', '00:00:01', '-i', video_path, '-vframes', '1', '-update', '1', poster_path
    }, '')
    if not ok or not file_exists(poster_path) then
      -- Try at 00:00:00 if 1s fails
      pcall(pandoc.pipe, 'ffmpeg', {
        '-y', '-ss', '00:00:00', '-i', video_path, '-vframes', '1', '-update', '1', poster_path
      }, '')
    end
  end
  return poster_path
end

-- Convert EPS to PDF using epstopdf / gs
local function eps_to_pdf(eps_path)
  local hash = get_hash(eps_path)
  local pdf_path = pandoc.path.join({tmpdir, 'eps-' .. hash .. '.pdf'})

  if no_cache or not file_exists(pdf_path) then
    local ok, _ = pcall(pandoc.pipe, 'epstopdf', {eps_path, '--outfile=' .. pdf_path}, '')
    if not ok or not file_exists(pdf_path) then
      pcall(pandoc.pipe, 'gs', {
        '-q', '-dNOPAUSE', '-dBATCH', '-sDEVICE=pdfwrite',
        '-sOutputFile=' .. pdf_path, eps_path
      }, '')
    end
  end
  return pdf_path
end

local function eps_to_png(eps_path)
  local hash = get_hash(eps_path)
  local png_path = pandoc.path.join({tmpdir, 'eps-' .. hash .. '.png'})
  if no_cache or not file_exists(png_path) then
    local pdf_path = eps_to_pdf(eps_path)
    local png_prefix = pandoc.path.join({tmpdir, 'eps-' .. hash})
    pcall(pandoc.pipe, 'pdftoppm', {'-png', '-r', '150', '-singlefile', pdf_path, png_prefix}, '')
    if not file_exists(png_path) and file_exists(png_prefix .. '.png') then
      png_path = png_prefix .. '.png'
    end
  end
  if file_exists(png_path) then
    return png_path
  end
  return nil
end

-- A standalone Markdown horizontal rule becomes an empty Beamer frame at
-- slide level. Section headings already provide the visual separation.
function HorizontalRule()
  if is_latex then return {} end
  return nil
end

-- Process Images (BPMN, SVG, Video, EPS, PNG, JPG)
function Image(img)
  local raw_src = img.src
  if raw_src:match('^https?://') or raw_src:match('^data:') then
    return img
  end

  local symbol_type = raw_src:match('^bpmn%-symbol:([%w]+)$')
  if symbol_type then
    local label = symbol_label(img.attributes.label) or symbol_label(img.caption)
    return symbol_inline(symbol_type, label, img.attributes)
  end

  local ext = raw_src:match('%.(%w+)$')
  if ext then ext = ext:lower() end
  
  local resolved_src = resolve_path(raw_src)
  
  -- Handle BPMN Diagrams
  if ext == 'bpmn' or (ext == 'xml' and img.classes:includes('bpmn')) then
    if not resolved_src then
      error(('slides: BPMN file not found: %s\n'):format(raw_src))
    end
    
    local scenario = img.attributes.scenario
    if scenario then scenario = resolve_path(scenario) or scenario end
    local animated = img.attributes.animated == 'true' or scenario ~= nil
    local bg = img.attributes.background
    local simulator = img.attributes.simulator == 'true' or img.attributes.simulator == '1'

    if simulator and is_marp then
      local id = bpmn_simulator_id(resolved_src)
      local html = bpmn_to_simulator_html(resolved_src, id, {
        background = bg,
        width = img.attributes.width,
        height = img.attributes.height,
        align = img.attributes.align and img.attributes.align:lower() or nil,
        include_assets = not simulator_assets_emitted,
      })
      simulator_assets_emitted = true
      return pandoc.RawInline('html', html)
    end

    local img_fast = is_fast
    if img.attributes.fast ~= nil then
      local fa = img.attributes.fast:lower()
      if fa == 'true' or fa == '1' or fa == 'yes' then
        img_fast = true
      elseif fa == 'false' or fa == '0' or fa == 'no' then
        img_fast = false
      end
    end

    local show_animation = animated and not img_fast
    
    if is_latex then
      -- PDFs are static: never run token simulation just to select a frame.
      local svg_path = bpmn_to_svg(resolved_src, bg)
      img.src = svg_to_pdf(svg_path)
      return latex_image(img)
    elseif is_marp then
      if show_animation then
        local anim_path = bpmn_to_webp(resolved_src, scenario, bg)
        local anim_data = file_to_data_uri(anim_path, 'image/webp')
        img.src = anim_data or anim_path
        return html_image(img.src, img.attributes, img.classes)
      else
        local svg_path = bpmn_to_svg(resolved_src, bg)
        local data_uri = file_to_data_uri(svg_path, 'image/svg+xml')
        img.src = data_uri or svg_path
        return html_image(img.src, img.attributes, img.classes)
      end
    end
  end
  
  -- Handle SVG
  if ext == 'svg' then
    if not resolved_src then
      error(('slides: SVG file not found: %s\n'):format(raw_src))
    end
    if is_latex then
      img.src = svg_to_pdf(resolved_src)
      return latex_image(img)
      elseif is_marp then
        local data_uri = file_to_data_uri(resolved_src, 'image/svg+xml')
        img.src = data_uri or resolved_src
        if is_marp then return html_image(img.src, img.attributes, img.classes) end
        return img
    end
  end

  -- Handle EPS
  if ext == 'eps' then
    if not resolved_src then
      error(('slides: EPS file not found: %s\n'):format(raw_src))
    end
    if is_latex then
      img.src = eps_to_pdf(resolved_src)
      return latex_image(img)
    elseif is_marp then
      local png_path = eps_to_png(resolved_src)
        if png_path then
          local data_uri = file_to_data_uri(png_path, 'image/png')
          img.src = data_uri or png_path
          if is_marp then return html_image(img.src, img.attributes, img.classes) end
          return img
      end
    end
  end
  
  -- Handle Videos (.mp4, .webm, .mov)
  if ext == 'mp4' or ext == 'webm' or ext == 'mov' then
    if is_latex then
      local poster = img.attributes.poster
      if poster then poster = resolve_path(poster) end
      if not poster and resolved_src then
        poster = extract_video_poster(resolved_src)
      end
      if poster and file_exists(poster) then
        img.src = poster
        return latex_image(img)
      end
    elseif is_marp then
      local autoplay = img.attributes.autoplay ~= 'false' and 'data-autoplay autoplay ' or ''
      local loop = img.attributes.loop ~= 'false' and 'loop ' or ''
      local muted = img.attributes.muted ~= 'false' and 'muted ' or ''
      local controls = img.attributes.controls ~= 'false' and 'controls ' or ''
      local styles = {}
      local classes = {'slides-video'}
      if img.attributes.width then table.insert(styles, 'width:' .. img.attributes.width) end
      if img.attributes.height then table.insert(styles, 'height:' .. img.attributes.height) end
      if img.attributes.align then
        local align = img.attributes.align:lower()
        if align == 'left' or align == 'center' or align == 'right' then
          table.insert(classes, 'align-' .. align)
        end
      end
      local style = #styles > 0 and ' style="' .. table.concat(styles, ';') .. '"' or ''
      local class = ' class="' .. table.concat(classes, ' ') .. '"'
      
      local video_src = raw_src
      if resolved_src and not raw_src:match('^https?://') then
        local content = read_file(resolved_src)
        if content and #content < 20 * 1024 * 1024 then
          video_src = 'data:' .. get_mime_type(ext) .. ';base64,' .. to_base64(content)
        end
      end

      return pandoc.RawInline('html', string.format(
        '<video%s src="%s"%s %s%s%s%splaysinline></video>',
        class, video_src, style, autoplay, loop, muted, controls
      ))
    end
  end
  
  -- Handle Standard Images (PNG, JPG, GIF, WebP, etc.)
  if is_marp then
    if resolved_src then
      local mime = get_mime_type(ext or '')
      local data_uri = file_to_data_uri(resolved_src, mime)
      if data_uri then
        img.src = data_uri
        if is_marp then return html_image(img.src, img.attributes, img.classes) end
        return img
      end
    end
  elseif is_latex then
    if resolved_src then
      img.src = resolved_src
    end
  end
  
  return is_latex and latex_image(img) or img
end

-- Render a standalone BPMN symbol inline in prose. The span content is used
-- as the BPMN label, so formatting remains concise in Markdown:
-- [Review request]{.bpmn-symbol type="userTask"}
function Span(span)
  local attr = span.attr
  if not attr.classes:includes('bpmn-symbol') then
    return span
  end

  local symbol_type = attr.attributes.type
  if not symbol_type or symbol_type == '' then
    error('slides: .bpmn-symbol requires a type attribute\n')
  end
  local label = symbol_label(span.content) or symbol_label(attr.attributes.label)
  return symbol_inline(symbol_type, label, attr.attributes)
end

-- Process CodeBlocks (Inline BPMN Diagrams)
function CodeBlock(block)
  if block.classes:includes('bpmn') then
    local hash = get_hash(block.text)
    local bpmn_path = pandoc.path.join({tmpdir, 'inline-' .. hash .. '.bpmn'})
    
    if not file_exists(bpmn_path) then
      local f = io.open(bpmn_path, 'w')
      if f then
        f:write(block.text)
        f:close()
      end
    end

    bpmn_autolayout(bpmn_path)

    if is_marp and block.classes:includes('simulator') then
      local id = bpmn_simulator_id(bpmn_path)
      local html = bpmn_to_simulator_html(bpmn_path, id, {
        background = block.attributes.background,
        width = block.attributes.width,
        height = block.attributes.height,
        align = block.attributes.align and block.attributes.align:lower() or nil,
        include_assets = not simulator_assets_emitted,
      })
      simulator_assets_emitted = true
      return pandoc.RawBlock('html', html)
    end

    if is_latex then
      local svg_path = bpmn_to_svg(bpmn_path, nil)
      local pdf_path = svg_to_pdf(svg_path)
      return pandoc.Para({pandoc.Image(pandoc.List(), pdf_path)})
    elseif is_marp then
      local svg_path = bpmn_to_svg(bpmn_path, nil)
      local data_uri = file_to_data_uri(svg_path, 'image/svg+xml')
      if is_marp then
        return pandoc.Para({html_image(data_uri or svg_path)})
      end
      return pandoc.Para({pandoc.Image(pandoc.List(), data_uri or svg_path)})
    end
  end
  return block
end

-- Marp uses horizontal rules as slide separators, while Pandoc's Markdown
-- writer keeps the heading hierarchy intact.
function Header(header)
  if is_marp and header.level == 2 then
    return pandoc.List({
      pandoc.RawBlock('markdown', '---'),
      header,
    })
  end
  return header
end

-- Beamer creates a title frame from document metadata. Marp needs that frame
-- represented explicitly in the Markdown stream.
function Pandoc(doc)
  if is_latex then
    local function is_notes_div(block)
      return block.t == 'Div' and block.classes and block.classes:includes('notes')
    end

    local function is_single_media_para(block)
      if block.t ~= 'Para' then return false end
      if #block.content ~= 1 then return false end
      local inline = block.content[1]
      if inline.t ~= 'Image' then return false end
      if inline.classes and inline.classes:includes('bpmn-symbol') then
        return false
      end
      return true
    end

    local function is_slide_header(block)
      return block.t == 'Header' and (block.level == 1 or block.level == 2)
    end

    local out = pandoc.List()
    local i = 1
    while i <= #doc.blocks do
      local block = doc.blocks[i]
      if block.t == 'Header' and block.level == 2 then
        out:insert(block)

        local j = i + 1
        local slide_blocks = pandoc.List()
        while j <= #doc.blocks and not is_slide_header(doc.blocks[j]) do
          slide_blocks:insert(doc.blocks[j])
          j = j + 1
        end

        local substantive = pandoc.List()
        for _, sb in ipairs(slide_blocks) do
          if not is_notes_div(sb) then
            substantive:insert(sb)
          end
        end

        if #substantive == 1 and is_single_media_para(substantive[1]) then
          for _, sb in ipairs(slide_blocks) do
            if sb == substantive[1] then
              out:insert(pandoc.RawBlock('latex', '\\vfill'))
              out:insert(sb)
              out:insert(pandoc.RawBlock('latex', '\\vfill'))
            else
              out:insert(sb)
            end
          end
        else
          out:extend(slide_blocks)
        end

        i = j
      else
        out:insert(block)
        i = i + 1
      end
    end

    doc.blocks = out
    return doc
  end

  local function is_slide_break(block)
    if not block then return false end
    if block.t == 'HorizontalRule' then return true end
    if block.t == 'RawBlock' and block.format == 'markdown' and block.text:match('^%s*%-%-%-%s*$') then
      return true
    end
    return false
  end

  local normalized_blocks = pandoc.List()
  local prev_block_is_break = (doc.meta.title ~= nil)

  for _, block in ipairs(doc.blocks) do
    -- The custom Pandoc pass below rebuilds the block list, so walk spans
    -- explicitly here instead of relying on the default filter traversal.
    block = pandoc.walk_block(block, {Span = Span})
    if block.t == 'Header' and block.level == 1 then
      if not prev_block_is_break then
        normalized_blocks:insert(pandoc.RawBlock('markdown', '---'))
      end
    end
    normalized_blocks:insert(block)
    if is_slide_break(block) then
      prev_block_is_break = true
    else
      prev_block_is_break = false
    end
  end

  if not doc.meta.title then
    doc.blocks = normalized_blocks
    return doc
  end

  local title = pandoc.utils.stringify(doc.meta.title)
  local title_blocks = pandoc.List({
    pandoc.RawBlock('markdown', '<!-- _class: title-slide -->'),
    pandoc.Header(1, {pandoc.Str(title)}),
  })
  local metadata_fields = {'subtitle', 'author', 'date', 'institute'}
  for _, field in ipairs(metadata_fields) do
    if doc.meta[field] then
      title_blocks:insert(pandoc.Para({pandoc.Str(pandoc.utils.stringify(doc.meta[field]))}))
    end
  end
  title_blocks:insert(pandoc.RawBlock('markdown', '---'))
  title_blocks:extend(normalized_blocks)
  doc.blocks = title_blocks
  return doc
end

-- Process Divs (Standout frames, Custom blocks)
function Div(div)
  if is_marp and div.classes:includes('column') and div.attributes.width then
    local width = div.attributes.width
    div.attributes.style = 'width:' .. width .. ';flex-basis:' .. width .. ';'
  end

  if div.classes:includes('diagram-caption') and is_latex then
    local blocks = pandoc.List({pandoc.RawBlock('latex', '\\begin{center}\\small\\color{slidemuted}')})
    blocks:extend(div.content)
    blocks:insert(pandoc.RawBlock('latex', '\\end{center}'))
    return blocks
  end

  if div.classes:includes('plain') then
    if is_latex then
      local blocks = pandoc.List({pandoc.RawBlock('latex', '\\begin{frame}[plain]')})
      blocks:extend(div.content)
      blocks:insert(pandoc.RawBlock('latex', '\\end{frame}'))
      return blocks
    end
  end
  
  return div
end

-- A linked image (`[![](img.png)](url)`) becomes `\href{url}{\pandocbounded{...}}`
-- in Beamer output. `\pandocbounded` (see beamer-metropolis.latex) starts and
-- ends with a bare `\par` to center the image as its own paragraph — safe on
-- its own, but `\par` inside `\href`'s argument forces vertical mode right
-- where hyperref needs to close the link, raising a fatal
-- "\pdfendlink cannot be used in vertical mode" error. A clickable image has
-- no benefit in a static PDF anyway, so just drop the link and keep the
-- image for LaTeX; Marp/HTML output (where this isn't an issue, and the
-- click-through is actually usable) keeps the link.
function Link(link)
  if is_latex and #link.content == 1 and link.content[1].t == 'Image' then
    return link.content
  end
  return link
end

-- Process Metadata
function Meta(meta)
  if not meta.aspectratio then
    meta.aspectratio = '169'
  end
  if not meta.fontsize then
    meta.fontsize = '12pt'
  end
  
  -- Handle theme colors
  if meta.colors then
    if meta.colors.primary then
      meta['theme-color-primary'] = pandoc.utils.stringify(meta.colors.primary):gsub('^#', '')
    end
    if meta.colors.accent then
      meta['theme-color-accent'] = pandoc.utils.stringify(meta.colors.accent):gsub('^#', '')
    end
  end

  -- Handle logo resolution
  if meta.logo then
    local logo_str = pandoc.utils.stringify(meta.logo)
    local resolved = resolve_path(logo_str)
    if resolved then
      local ext = resolved:match('%.(%w+)$')
      if ext then ext = ext:lower() end
      if is_latex then
        if ext == 'eps' then
          meta.logo = pandoc.MetaString(eps_to_pdf(resolved))
        elseif ext == 'svg' then
          meta.logo = pandoc.MetaString(svg_to_pdf(resolved))
        else
          meta.logo = pandoc.MetaString(resolved)
        end
      elseif is_marp then
        if ext == 'eps' then
          local png_path = eps_to_png(resolved)
          if png_path then
            local data_uri = file_to_data_uri(png_path, 'image/png')
            meta.logo = pandoc.MetaString(data_uri or resolved)
          end
        else
          local mime = get_mime_type(ext or '')
          local data_uri = file_to_data_uri(resolved, mime)
          meta.logo = pandoc.MetaString(data_uri or resolved)
        end
      end
    end
  end
  
  -- Handle fast mode
  if meta.fast ~= nil then
    local v = pandoc.utils.stringify(meta.fast):lower()
    if v == 'false' or v == '0' or v == 'no' or meta.fast == false then
      is_fast = false
    elseif v == 'true' or v == '1' or v == 'yes' or meta.fast == true or v == '' then
      is_fast = true
    end
  end

  return meta
end

return {
  { Meta = Meta },
  {
    Pandoc = Pandoc,
    Header = Header,
    Div = Div,
    Link = Link,
    CodeBlock = CodeBlock,
    HorizontalRule = HorizontalRule,
    Image = Image,
  }
}
