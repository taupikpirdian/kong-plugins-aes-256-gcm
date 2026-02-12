local typedefs = require "kong.db.schema.typedefs"

return {
    name = "response-aes-encrypt",
    fields = {
        { protocols = typedefs.protocols_http },
        { config = {
            type = "record",
            fields = {
                { fail_encrypt_status = { type = "number", default = 500 } },
                { fail_encrypt_message = { type = "string", default = "Encryption failed" } },
                { secret_key = { type = "string", required = true } },
                { additional_headers = { type = "boolean", default = true } }
            }
        }
        }
    }
}
