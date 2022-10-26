-- TODO: code cleanup
local Spinner = {}
--> from fidget.nvim
local list = { "⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏" }

function Spinner:start(s)
    local block = s.code_block
    local r, c = block['start'].row, block['start'].column
    local t = vim.loop.new_timer()

    local idx = 0
    local id = vim.api.nvim_buf_set_extmark(
        s.buf,
        s.ns,
        r, c, {
            virt_text_pos = 'eol',
            virt_text={{list[idx+1], 'Function'}}
        }
    )

    Spinner.state = {
        id = id,
        buf = s.buf, ns = s.ns,
        r=r, c=c, t=t
    }

    t:start(0, 100, vim.schedule_wrap(function()
        idx = (idx + 1) % #list
        vim.api.nvim_buf_set_extmark(
            s.buf,
            s.ns,
            Spinner.state.r, Spinner.state.c,
            { virt_text = {{list[idx+1], 'Function'}}, id=Spinner.state.id }
        )
    end))
end

function Spinner:shut()
    local s = Spinner.state
    vim.api.nvim_buf_del_extmark(s.buf, s.ns, s.id)
    s.t:stop()
end

return Spinner
