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
  if file_exists(src) then
    return src
  end
  if PANDOC_STATE and PANDOC_STATE.input_files and #PANDOC_STATE.input_files > 0 then
    local doc_dir = pandoc.path.directory(PANDOC_STATE.input_files[1])
    if doc_dir and doc_dir ~= '' and doc_dir ~= '.' then
      local candidate1 = pandoc.path.join({doc_dir, src})
      if file_exists(candidate1) then
        return candidate1
      end
      local candidate2 = pandoc.path.join({doc_dir, '..', src})
      if file_exists(candidate2) then
        return candidate2
      end
    end
  end
  return nil
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

-- Process Images (BPMN, SVG, Video, EPS, PNG, JPG)
function Image(img)
  local raw_src = img.src
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
        if anim_format == 'mp4' or anim_format == 'webm' then
          return pandoc.RawInline('html', string.format(
            '<video src="%s" data-autoplay autoplay loop muted controls playsinline style="max-width:100%%; max-height:70vh; margin:0 auto; display:block;"></video>',
            anim_path
          ))
        else
          img.src = anim_path
          return img
        end
      else
        local svg_path = bpmn_to_svg(resolved_src, bg)
        img.src = svg_path
        return img
      end
    end
  end
  
  -- Handle SVG in LaTeX / Beamer
  if ext == 'svg' and is_latex then
    if not resolved_src then
      error(('slides: SVG file not found: %s\n'):format(raw_src))
    end
    img.src = svg_to_pdf(resolved_src)
    return img
  end

  -- Handle EPS in LaTeX / Beamer
  if ext == 'eps' and is_latex then
    if not resolved_src then
      error(('slides: EPS file not found: %s\n'):format(raw_src))
    end
    img.src = eps_to_pdf(resolved_src)
    return img
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
      
      return pandoc.RawInline('html', string.format(
        '<video src="%s" %s%s%s%splaysinline style="max-width:100%%; max-height:70vh; margin:0 auto; display:block;"></video>',
        resolved_src or raw_src, autoplay, loop, muted, controls
      ))
    end
  end
  
  if resolved_src then
    img.src = resolved_src
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
      return pandoc.Para({pandoc.Image(pandoc.List(), svg_path)})
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
      if ext == 'eps' and is_latex then
        meta.logo = pandoc.MetaString(eps_to_pdf(resolved))
      elseif ext == 'svg' and is_latex then
        meta.logo = pandoc.MetaString(svg_to_pdf(resolved))
      else
        meta.logo = pandoc.MetaString(resolved)
      end
    end
  end
  
  return meta
end
