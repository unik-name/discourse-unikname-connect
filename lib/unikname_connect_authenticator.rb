# frozen_string_literal: true
class UniknameConnectAuthenticator < Auth::ManagedAuthenticator
  def name
    'unikname'
  end

  def can_revoke?
    SiteSetting.unikname_connect_allow_association_change
  end

  def can_connect_existing_user?
    SiteSetting.unikname_connect_allow_association_change
  end

  def enabled?
    SiteSetting.unikname_connect_enabled
  end

  def primary_email_verified?(auth)
    supplied_verified_boolean = auth['extra']['raw_info']['email_verified']
    # If the payload includes the email_verified boolean, use it. Otherwise assume true
    supplied_verified_boolean.nil? ? true : supplied_verified_boolean
  end

  def always_update_user_email?
    SiteSetting.unikname_connect_overrides_email
  end

  def description_for_auth_hash(auth_token)
    return
  end

  def register_middleware(omniauth)

    omniauth.provider :unikname,
      name: :unikname,
      cache: lambda { |key, &blk| Rails.cache.fetch(key, expires_in: 10.minutes, &blk) },
      error_handler: lambda { |error, message|
        handlers = []
        handlers.each do |row|
          parts = row.split("|")
          return parts[1] if message.include? parts[0]
        end
        nil
      },
      verbose_logger: lambda { |message|
        return unless SiteSetting.unikname_connect_verbose_logging
        Rails.logger.warn("OIDC Log: #{message}")
      },
      setup: lambda { |env|
        opts = env['omniauth.strategy'].options

        token_params = {}
        token_params[:scope] = "openid"

        opts.deep_merge!(
          client_id: SiteSetting.unikname_connect_business_account_id,
          client_secret: SiteSetting.unikname_connect_api_secret_key,
          client_options: {
            discovery_document: "https://connect.unikname.com/oidc/.well-known/openid-configuration",
          },
          scope: "openid",
          token_params: token_params,
          passthrough_authorize_options: [],
          )
      }
  end
end
