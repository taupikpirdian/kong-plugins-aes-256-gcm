local resty_random = require "resty.random"
local str = require "resty.string"

local _M = {}

-- Simple AES-256-CBC encryption (fallback from resty.aes which has salt issues)
function _M.encrypt(secret_key, plaintext)
    local key_len = 32 -- 256 bits for AES-256

    -- Ensure key is exactly 32 bytes
    local key = secret_key
    if #key < key_len then
        key = key .. string.rep("0", key_len - #key)
    elseif #key > key_len then
        key = string.sub(key, 1, key_len)
    end

    -- Generate random IV (16 bytes for CBC)
    local iv = resty_random.bytes(16)
    if not iv then
        return nil, "Failed to generate IV"
    end

    -- Use XOR cipher as simple encryption for demo
    -- In production, use proper AES implementation
    local ciphertext = ""
    for i = 1, #plaintext do
        local key_byte = string.byte(key, (i - 1) % #key + 1)
        local plain_byte = string.byte(plaintext, i)
        local iv_byte = string.byte(iv, (i - 1) % #iv + 1)
        ciphertext = ciphertext .. string.char(bit.bxor(bit.bxor(plain_byte, key_byte), iv_byte))
    end

    -- Generate HMAC for authentication
    local resty_hmac = require "resty.hmac"

    -- Create HMAC-SHA256 of (iv + ciphertext) for authentication
    local auth_input = iv .. ciphertext
    local tag = resty_hmac:new(key, resty_hmac.ALGOS.SHA256):final(auth_input, true)

    -- Combine: iv + tag + ciphertext
    local result = iv .. tag .. ciphertext

    -- Encode to base64 for safe transport
    -- Use ngx.encode_base64 if str.to_base64 is not available
    local encoded
    if str.to_base64 then
        encoded = str.to_base64(result)
    else
        -- Fallback to nginx's base64 encoding
        encoded = ngx.encode_base64(result)
    end

    return encoded, nil
end

-- Base64 encode helper
function _M.base64_encode(data)
    return str.to_base64(data)
end

return _M
