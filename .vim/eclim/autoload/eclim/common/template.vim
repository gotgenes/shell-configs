" Author:  Eric Van Dewoestine
" Version: $Revision$
"
" Description: {{{
"
" License:
"
" Copyright (C) 2005 - 2009  Eric Van Dewoestine
"
" This program is free software: you can redistribute it and/or modify
" it under the terms of the GNU General Public License as published by
" the Free Software Foundation, either version 3 of the License, or
" (at your option) any later version.
"
" This program is distributed in the hope that it will be useful,
" but WITHOUT ANY WARRANTY; without even the implied warranty of
" MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
" GNU General Public License for more details.
"
" You should have received a copy of the GNU General Public License
" along with this program.  If not, see <http://www.gnu.org/licenses/>.
"
" }}}

" Global Variables {{{
if !exists("g:EclimTemplateDir")
  let g:EclimTemplateDir = g:EclimBaseDir . '/template'
endif
if !exists("g:EclimTemplateExtension")
  let g:EclimTemplateExtension = '.vim'
endif
if !exists("g:EclimTemplateIgnore")
  let g:EclimTemplateIgnore = []
endif
" }}}

" Script Variables {{{
let s:quote = "['\"]"
let s:tag_regex =
  \ '<vim:[a-zA-Z]\+\(\s\+[a-zA-Z]\+\s*=\s*' . s:quote . '.*' . s:quote . '\)\?\s*/>'
let s:tagname_regex = '.\{-}<vim:\([a-zA-Z]\+\).*'
" }}}

" Template() {{{
" Main method for finding and executing the template.
function! eclim#common#template#Template()
  " allow some plugins to disable templates temporarily
  if exists('g:EclimTemplateTempIgnore') && g:EclimTemplateTempIgnore
    return
  endif

  " ignore certain file patterns
  for ignore in g:EclimTemplateIgnore
    if expand('%') =~ ignore
      return
    endif
  endfor

  let template = s:FindTemplate()
  if template != ''
    silent exec "read " . template
    call cursor(1, 1)
    delete _

    call s:ExecuteTemplate()
  endif
endfunction " }}}

" s:FindTemplate() {{{
" Finds the template file and returns the location.
function! s:FindTemplate()
  let templatesDir = expand(g:EclimTemplateDir)
  if !isdirectory(templatesDir)
    call eclim#util#EchoError("No such directory: " . templatesDir)
    return ''
  endif

  let filename = expand('%:t')
  let ext = ""

  " template equal to the filename
  if filereadable(templatesDir . '/' . filename . g:EclimTemplateExtension)
    return templatesDir . '/' . filename . g:EclimTemplateExtension
  endif

  " template pattern
  let templates = globpath(templatesDir, '*' . g:EclimTemplateExtension)
  for template in split(templates, '\n')
    " remove path info
    let temp_template = substitute(template, '.*[/\\]', '', '')
    if g:EclimTemplateExtension != ''
      let temp_template =
        \ strpart(temp_template, 0, stridx(temp_template, g:EclimTemplateExtension))
    endif

    while stridx(temp_template, '.') != -1
      let ext = strpart(temp_template, stridx(temp_template, '.'))
      let temp_template = strpart(temp_template, 0, stridx(temp_template, '.'))
      if filename =~ '.*' . temp_template . '.*' . ext
        return template
      endif
    endwhile
  endfor

  " template equal to file extension
  if stridx(filename, '.') > 0
    let ext = strpart(filename, stridx(filename, '.'))
    while stridx(ext, '.') != -1
      let ext = strpart(ext, stridx(ext, '.') + 1)
      if filereadable(templatesDir . '/' . ext . g:EclimTemplateExtension)
        return templatesDir . '/' . ext . g:EclimTemplateExtension
      endif
    endwhile
  endif

  " template equal to file type
  if filereadable(templatesDir . '/' . &ft . g:EclimTemplateExtension)
    return templatesDir . '/' . &ft . g:EclimTemplateExtension
  endif

  return ''
endfunction " }}}

" s:ExecuteTemplate() {{{
" Executes any logic in the template.
function! s:ExecuteTemplate()
  let line = 1
  while line <= line('$')
    let currentLine = getline(line)
    while currentLine =~ s:tag_regex
      let tag = substitute(currentLine, s:tagname_regex, '\1', '')
      let line = s:Process_{tag}(line)
      let currentLine = getline(line)
    endwhile
    let line = line + 1
  endwhile
endfunction " }}}

" s:EvaluateExpression(expression) {{{
" Evaluates the supplied expression.
function! s:EvaluateExpression(expression)
  exec "return " . a:expression
endfunction " }}}

" s:GetAttribute(line, tag, attribute, fail) {{{
" Gets the an attribute value.
function! s:GetAttribute(line, tag, attribute, fail)
  let attribute = substitute(a:line,
    \ '.\{-}<vim:' . a:tag . '.\{-}\s\+' . a:attribute .
      \ '\s*=\s*\(' . s:quote . '\)\(.\{-}\)\1.*/>.*',
    \ '\2', '')

  if attribute == a:line
    if a:fail
      call s:TemplateError(
        \ a:line, "syntax error - missing '" . a:attribute . "' attribute")
    endif
    return ""
  endif
  return attribute
endfunction " }}}

" s:TemplateError(line, message) {{{
" Echos an error message to the user.
function! s:TemplateError(line, message)
  call eclim#util#EchoError("Template error, line " . a:line . ": " . a:message)
endfunction " }}}

" s:Process_var(line) {{{
" Process <vim:var/> tags.
function! s:Process_var(line)
  let currentLine = getline(a:line)

  let name = expand(s:GetAttribute(currentLine, 'var', 'name', 1))
  let value = expand(s:GetAttribute(currentLine, 'var', 'value', 1))

  exec "let " . name . " = \"" .  s:EvaluateExpression(value) . "\""

  silent exec a:line . "delete _"

  return a:line - 1
endfunction " }}}

" s:Process_import(line) {{{
" Process <vim:import/> tags.
function! s:Process_import(line)
  let currentLine = getline(a:line)

  let resource = expand(s:GetAttribute(currentLine, 'import', 'resource', 1))
  if resource !~ '^/\'
    let resource = expand(g:EclimTemplateDir . '/' . resource)
  endif

  if !filereadable(resource)
    call s:TemplateError(a:line, "resource not found '" . resource . "'")
  endif

  exec "source " . resource
  silent exec a:line . "delete _"

  return a:line - 1
endfunction " }}}

" s:Process_out(line) {{{
" Process <vim:out/> tags.
function! s:Process_out(line)
  let currentLine = getline(a:line)
  let value = s:GetAttribute(currentLine, 'out', 'value', 1)
  let result = s:EvaluateExpression(value)
  return s:Out(a:line, '<vim:out\s\+.\{-}\s*\/>', result)
endfunction " }}}

" s:Process_include(line) {{{
" Process <vim:include/> tags.
function! s:Process_include(line)
  let currentLine = getline(a:line)
  let template = expand(
    \ g:EclimTemplateDir . '/' . s:GetAttribute(currentLine, 'include', 'template', 1))

  if !filereadable(template)
    call s:TemplateError(a:line, "template not found '" . template . "'")
  endif

  exec "read " . template
  call cursor(a:line, 1)
  silent exec a:line . "delete _"

  return a:line
endfunction " }}}

" s:Process_username(line) {{{
" Process <vim:username/> tags.
function! s:Process_username(line)
  let username = eclim#project#util#GetProjectSetting('org.eclim.user.name')
  if type(username) == 0
    let username = ''
  endif
  return s:Out(a:line, '<vim:username\s*\/>', username)
endfunction " }}}

" s:Out(line, pattern, value) {{{
function! s:Out(line, pattern, value)
  let currentLine = getline(a:line)

  let results = type(a:value) == 3 ? a:value : [a:value]
  if results[0] == '' && currentLine =~ '^\s*' . a:pattern . '\s*$'
    exec a:line . 'delete _'
    return a:line - 1
  endif

  exec a:line . 'substitute/' . a:pattern . '/' . escape(results[0], '/') . '/'
  call append(a:line, results[1:])

  return a:line
endfunction " }}}

" vim:ft=vim:fdm=marker
