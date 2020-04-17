" My personal Python configuration settings.

" This setting looks for tags files, recursively upwards
setlocal tags+=tags;$HOME

" Use Ropevim if possible
if filereadable($HOME . '/.local/ropevim.vim')
  "autocmd FileType python source $HOME/.local/ropevim.vim
  source $HOME/.local/ropevim.vim
endif

" Python cTags for omni-complete [TODO: Forget about this and just use
" Ropevim]
" Make sure to have run
" ctags -R -f ~/.vim/tags/python.ctags /usr/lib/pythonX.Y/
" where X is the major version and Y is the point release installed on your
" system
if filereadable(expand("$HOME/.vim/tags/python.ctags"))
  setlocal tags+=$HOME/.vim/tags/python.ctags
endif
