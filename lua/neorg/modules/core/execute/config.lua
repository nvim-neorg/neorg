return {
    lang_cmds = {
        --> Interpreted
        python = {
            cmd='python3 ${0}', type = 'interpreted'
        },
        lua = {
            cmd='lua ${0}', type='interpreted'
        },
        javascript = {
            cmd='node ${0}',
            type='interpreted'
        },
        bash = {
            cmd='bash ${0}', type='interpreted'
        },
        php = {
            cmd='php ${0}', type='interpreted'
        },
        ruby = {
            cmd='ruby ${0}', type='interpreted'
        },

        --> Compiled
        cpp = {
            cmd='g++ ${0} && ./a.out && rm ./a.out',
            type='compiled',
            main_wrap = [[
            #include <iostream>
            int main() {
                ${1}
            }
            ]]
        },
        c = {
            cmd='gcc ${0} && ./a.out && rm ./a.out',
            type='compiled',
            main_wrap = [[
            #include <stdio.h>
            #include <stdlib.h>

            int main() {
                ${1}
            }
            ]]
        },
        rust = {
            cmd='rustc ${0} -o ./a.out && ./a.out && rm ./a.out',
            type = 'compiled',
            main_wrap = [[
            fn main() {
                ${1}
            }
            ]]
        }
    },
}
