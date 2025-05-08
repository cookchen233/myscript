set number
set backspace=indent,eol,start
set ruler
set showmode
set bg=light
set showcmd
set clipboard+=unnamed
set tabstop=4
set shiftwidth=4
set expandtab
let g:rg_command = '
  \ rg --column --line-number --no-heading --fixed-strings --ignore-case --no-ignore --hidden --follow --color "always"
  \ -g "*.{js,json,php,md,styl,jade,html,config,py,cpp,c,go,hs,rb,conf}"
  \ -g "!{.git,node_modules,vendor}/*" '

command! -bang -nargs=* F call fzf#vim#grep(g:rg_command .shellescape(<q-args>), 1, <bang>0)

" 设置 leader 键为逗号（可选，方便按）
let mapleader = ","

" 快速保存
nnoremap <leader>s :w<CR>
nnoremap ss :w<CR>

" 快速退出
nnoremap <leader>q :q!CR>
nnoremap qq :q!<CR>

" 快速保存并退出
nnoremap <leader>w :wq<CR>
nnoremap ww :wq<CR>