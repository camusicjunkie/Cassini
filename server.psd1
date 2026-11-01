# Pode server settings (read by Start-PodeServer from the root path).
@{
    Server = @{
        Request = @{
            # Approve-WsusRing walks every Pilot approval with per-group summaries; on a large catalog
            # the preview takes well over Pode's default 30 seconds. Keep in step with requestTimeout
            # in web.config.
            Timeout = 300
        }
    }
    Web    = @{
        Static = @{
            Cache = @{
                Enable = $true
            }
        }
    }
}
