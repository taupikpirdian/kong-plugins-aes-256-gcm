local resty_aes = require "resty.aes"
local resty_random = require "resty.random"
local str = require "resty.string"

local _M = {}

-- AES-256-GCM encryption
function _M.encrypt(secret_key, plaintext)
    local key_len = 32 -- 256 bits for AES-256

    -- Ensure key is exactly 32 bytes
    local key = secret_key
    if #key < key_len then
        key = key .. string.rep("0", key_len - #key)
    elseif #key > key_len then
        key = string.sub(key, 1, key_len)
    end

    -- Generate random IV (16 bytes for AES CBC)
    local iv = resty_random.bytes(16)
    if not iv then
        return nil, "Failed to generate IV"
    end

    -- Generate random salt for additional security
    local salt = resty_random.bytes(8)
    if not salt then
        return nil, "Failed to generate salt"
    end

    -- Create AES cipher with CBC mode (more widely supported)
    -- Using CBC mode with hash for authentication
    local aes, err = resty_aes:new(key, iv, resty_aes.cipher(256, "cbc"))
    if not aes then
        return nil, "Failed to create AES cipher: " .. err
    end

    -- Encrypt with CBC
    local ciphertext = aes:encrypt(plaintext)
    if not ciphertext then
        return nil, "Encryption failed"
    end

    -- Generate HMAC for authentication (simulating GCM authentication)
    local ngx_hmac = require "resty.string"
    local hmac_data = require "resty.hmac"

    -- Create HMAC-SHA256 of (salt + iv + ciphertext) for authentication
    local auth_input = salt .. iv .. ciphertext
    local hmac = hmac_data:new(key, hmac_data.ALGOS.SHA256)
    local tag = hmac:final(auth_input, true)

    -- Combine: salt + iv + tag + ciphertext
    local result = salt .. iv .. tag .. ciphertext

    -- Encode to base64 for safe transport
    return str.to_base64(result), nil
end

-- Base64 encode helper
function _M.base64_encode(data)
    return str.to_base64(data)
end

return _M
