local aes_gcm = require "kong.plugins.response-aes-encrypt.aes-gcm"
local kong = kong

local ResponseAesEncryptHandler = {
    VERSION = "1.0.0",
    PRIORITY = 1000,
}

-- Flag to track if encryption failed in header_filter
local encryption_failed = false

-- Modify response headers before body is sent
function ResponseAesEncryptHandler:header_filter(conf)
    -- Skip if response is from exit (error response)
    if kong.response.get_source() == "exit" then
        return
    end

    -- Skip for OPTIONS requests
    if kong.request.get_method() == "OPTIONS" then
        return
    end

    -- Clear original Content-Length as body will change
    kong.response.clear_header("Content-Length")

    -- Set custom content type to indicate encrypted response
    if conf.additional_headers then
        kong.response.set_header("Content-Type", "application/aes-256-gcm+json")
        kong.response.set_header("X-Encrypted", "AES-256-GCM")
    end
end

-- Encrypt response body
function ResponseAesEncryptHandler:body_filter(conf)
    -- Skip if response is from exit (error response)
    if kong.response.get_source() == "exit" then
        return
    end

    -- Skip for OPTIONS requests
    if kong.request.get_method() == "OPTIONS" then
        return
    end

    -- Get the response body
    local chunk, eof = kong.response.get_raw_body()

    if chunk then
        -- Encrypt the chunk
        local encrypted, err = aes_gcm.encrypt(conf.secret_key, chunk)

        if not encrypted then
            -- Log error and return original body in case of encryption failure
            kong.log.err("AES encryption failed: ", err)
            kong.log.err("Returning original response body")

            -- Return the original chunk unencrypted
            kong.response.set_raw_body(chunk)

            -- Set error header to indicate encryption failed
            kong.response.set_header("X-Encryption-Error", "true")
            kong.response.set_header("X-Encryption-Error-Message", conf.fail_encrypt_message or "Encryption failed")
            return
        end

        -- Set encrypted body
        kong.response.set_raw_body(encrypted)
    end
end

return ResponseAesEncryptHandler
