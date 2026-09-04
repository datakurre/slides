-- Pandoc Lua filter for presentation slides (Beamer PDF & Reveal.js HTML)
--
-- Features:
-- 1. BPMN 2.0 diagrams (.bpmn, .xml, ```bpmn code blocks) rendered to SVG/PDF via bpmn-to-image
-- 2. SVG images converted to PDF via rsvg-convert for pdflatex
-- 3. MP4/WebM videos: native HTML5 <video> in Reveal.js, ffmpeg poster snapshot in Beamer PDF
-- 4. Standout slides and presentation helpers across both backends

local is_latex = FORMAT:match('latex') or FORMAT:match('beamer')
local is_html = FORMAT:match('html') or FORMAT:match('revealjs')

local tmpdir = os.getenv('SLIDES_TMPDIR') or os.getenv('TMPDIR') or '/tmp'

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

-- Convert BPMN XML to SVG using bpmn-to-image
local function bpmn_to_svg(bpmn_path, bg_color)
  local hash = get_hash(bpmn_path .. (bg_color or ''))
  local svg_path = pandoc.path.join({tmpdir, 'bpmn-' .. hash .. '.svg'})
  
  if not file_exists(svg_path) then
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
  return svg_path
end

-- Convert SVG to PDF using rsvg-convert
local function svg_to_pdf(svg_path)
  local hash = get_hash(svg_path)
  local pdf_path = pandoc.path.join({tmpdir, 'svg-' .. hash .. '.pdf'})
  
  if not file_exists(pdf_path) then
    local ok, err = pcall(pandoc.pipe, 'rsvg-convert', {'--format=pdf', '--output=' .. pdf_path, svg_path}, '')
    if not ok then
      error(('slides: rsvg-convert failed for %s:\n%s\n'):format(svg_path, tostring(err)))
    end
  end
  return pdf_path
end

-- Convert BPMN to animated MP4 / GIF for HTML slides
local function bpmn_to_video(bpmn_path, scenario_path, format)
  local fmt = format or 'mp4'
  local hash = get_hash(bpmn_path .. (scenario_path or '') .. fmt)
  local out_path = pandoc.path.join({tmpdir, 'bpmn-anim-' .. hash .. '.' .. fmt})
  
  if not file_exists(out_path) then
    local args = {'--format', fmt}
    if scenario_path and file_exists(scenario_path) then
      table.insert(args, '--scenario')
      table.insert(args, scenario_path)
    end
    table.insert(args, bpmn_path)
    table.insert(args, out_path)
    
    local ok, err = pcall(pandoc.pipe, 'bpmn-to-image', args, '')
    if not ok then
      error(('slides: bpmn-to-image animation failed for %s:\n%s\n'):format(bpmn_path, tostring(err)))
    end
  end
  return out_path
end

-- Extract poster frame from video using ffmpeg
local function extract_video_poster(video_path)
  local hash = get_hash(video_path)
  local poster_path = pandoc.path.join({tmpdir, 'video-poster-' .. hash .. '.png'})
  
  if not file_exists(poster_path) then
    local ok, _ = pcall(pandoc.pipe, 'ffmpeg', {
      '-y', '-ss', '00:00:01', '-i', video_path, '-vframes', '1', poster_path
    }, '')
    if not ok or not file_exists(poster_path) then
      -- Try at 00:00:00 if 1s fails
      pcall(pandoc.pipe, 'ffmpeg', {
        '-y', '-ss', '00:00:00', '-i', video_path, '-vframes', '1', poster_path
      }, '')
    end
  end
  return poster_path
end

-- Convert EPS to PDF using epstopdf / gs
local function eps_to_pdf(eps_path)
  local hash = get_hash(eps_path)
  local pdf_path = pandoc.path.join({tmpdir, 'eps-' .. hash .. '.pdf'})
  
  if not file_exists(pdf_path) then
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
  if not file_exists(png_path) then
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

-- Process Images (BPMN, SVG, Video, EPS, PNG, JPG)
function Image(img)
  local raw_src = img.src
  if raw_src:match('^https?://') or raw_src:match('^data:') then
    return img
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
    local bg = img.attributes.background or (is_latex and 'white' or nil)
    
    if is_latex then
      local svg_path = bpmn_to_svg(resolved_src, bg or 'white')
      local pdf_path = svg_to_pdf(svg_path)
      img.src = pdf_path
      return img
    elseif is_html then
      if animated then
        local anim_format = img.attributes.format or 'mp4'
        local anim_path = bpmn_to_video(resolved_src, scenario, anim_format)
        local anim_data = file_to_data_uri(anim_path, get_mime_type(anim_format))
        local anim_src = anim_data or anim_path
        if anim_format == 'mp4' or anim_format == 'webm' then
          return pandoc.RawInline('html', string.format(
            '<video src="%s" data-autoplay autoplay loop muted controls playsinline style="max-width:100%%; max-height:70vh; margin:0 auto; display:block;"></video>',
            anim_src
          ))
        else
          img.src = anim_src
          return img
        end
      else
        local svg_path = bpmn_to_svg(resolved_src, bg)
        local data_uri = file_to_data_uri(svg_path, 'image/svg+xml')
        img.src = data_uri or svg_path
        return img
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
      return img
    elseif is_html then
      local data_uri = file_to_data_uri(resolved_src, 'image/svg+xml')
      img.src = data_uri or resolved_src
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
      return img
    elseif is_html then
      local png_path = eps_to_png(resolved_src)
      if png_path then
        local data_uri = file_to_data_uri(png_path, 'image/png')
        img.src = data_uri or png_path
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
        return img
      end
    elseif is_html then
      local autoplay = img.attributes.autoplay ~= 'false' and 'data-autoplay autoplay ' or ''
      local loop = img.attributes.loop ~= 'false' and 'loop ' or ''
      local muted = img.attributes.muted ~= 'false' and 'muted ' or ''
      local controls = img.attributes.controls ~= 'false' and 'controls ' or ''
      
      local video_src = raw_src
      if resolved_src and not raw_src:match('^https?://') then
        local content = read_file(resolved_src)
        if content and #content < 20 * 1024 * 1024 then
          video_src = 'data:' .. get_mime_type(ext) .. ';base64,' .. to_base64(content)
        end
      end

      return pandoc.RawInline('html', string.format(
        '<video src="%s" %s%s%s%splaysinline style="max-width:100%%; max-height:70vh; margin:0 auto; display:block;"></video>',
        video_src, autoplay, loop, muted, controls
      ))
    end
  end
  
  -- Handle Standard Images (PNG, JPG, GIF, WebP, etc.)
  if is_html then
    if resolved_src then
      local mime = get_mime_type(ext or '')
      local data_uri = file_to_data_uri(resolved_src, mime)
      if data_uri then
        img.src = data_uri
        return img
      end
    end
  elseif is_latex then
    if resolved_src then
      img.src = resolved_src
    end
  end
  
  return img
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
    
    if is_latex then
      local svg_path = bpmn_to_svg(bpmn_path, 'white')
      local pdf_path = svg_to_pdf(svg_path)
      return pandoc.Para({pandoc.Image(pandoc.List(), pdf_path)})
    elseif is_html then
      local svg_path = bpmn_to_svg(bpmn_path, nil)
      local data_uri = file_to_data_uri(svg_path, 'image/svg+xml')
      return pandoc.Para({pandoc.Image(pandoc.List(), data_uri or svg_path)})
    end
  end
  return block
end

-- Process Divs (Standout frames, Custom blocks)
function Div(div)
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
      elseif is_html then
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
  
  return meta
end
