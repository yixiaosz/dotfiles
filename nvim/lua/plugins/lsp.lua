return {
    -- 1. Mason: downloads and manages LSP server binaries
    {
        "mason-org/mason.nvim",
        opts = {},
    },

    -- 2. mason-lspconfig: bridges Mason ↔ Neovim's LSP client
    --    `automatic_enable = true` (default) means mason-lspconfig will call
    --    vim.lsp.enable() for every Mason-installed server automatically.
    {
        "mason-org/mason-lspconfig.nvim",
        opts = {
            ensure_installed = {
                "pyright",  -- Python
                "clangd",   -- C / C++
                "jdtls",    -- Java
            },
        },
        dependencies = {
            "mason-org/mason.nvim",
            "neovim/nvim-lspconfig",
        },
    },

    -- 3. nvim-lspconfig: ships server configs consumed by vim.lsp.enable()
    {
        "neovim/nvim-lspconfig",
        config = function()

            -- Explicitly enable each server.
            -- (mason-lspconfig's automatic_enable does this too, but being
            -- explicit here keeps the config self-documenting.)
            vim.lsp.enable("pyright")
            vim.lsp.enable("clangd")
            vim.lsp.enable("jdtls")  -- workspace dir is handled automatically
                                     -- by nvim-lspconfig's built-in jdtls config

            -- ── On LSP Attach ─────────────────────────────────────────────
            vim.api.nvim_create_autocmd("LspAttach", {
                callback = function(event)
                    local client = vim.lsp.get_client_by_id(event.data.client_id)

                    -- Native completion (Neovim 0.11+, no extra plugin needed)
                    if client and client:supports_method("textDocument/completion") then
                        vim.lsp.completion.enable(true, client.id, event.buf, {
                            autotrigger = true,  -- popup appears automatically as you type
                        })
                    end

                    -- ── Keymaps ───────────────────────────────────────────
                    local map = function(keys, func, desc)
                        vim.keymap.set("n", keys, func, {
                            buffer = event.buf,
                            desc = "LSP: " .. desc,
                        })
                    end

                    -- Navigation
                    map("gd", vim.lsp.buf.definition,     "Go to Definition")
                    map("gD", vim.lsp.buf.declaration,    "Go to Declaration")
                    map("gi", vim.lsp.buf.implementation, "Go to Implementation")
                    map("gr", vim.lsp.buf.references,     "Go to References")

                    -- Documentation
                    map("K",  vim.lsp.buf.hover,          "Hover Documentation")

                    -- Editing
                    map("<leader>rn", vim.lsp.buf.rename,      "Rename Symbol")
                    map("<leader>ca", vim.lsp.buf.code_action, "Code Action")
                    map("<leader>f",  vim.lsp.buf.format,      "Format File")

                    -- Diagnostics
                    map("[d", vim.diagnostic.goto_prev,        "Previous Diagnostic")
                    map("]d", vim.diagnostic.goto_next,        "Next Diagnostic")
                    map("<leader>e", vim.diagnostic.open_float, "Show Diagnostic")
                end,
            })
        end,
    },
}
