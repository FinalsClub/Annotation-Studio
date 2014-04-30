# i18n's old behavior was to not validate locales when
# certain things were done with it. This behavior is now
# deprecated, but is still the default. When i18n defaults
# to the deprecated behavior, it prints a warning message.
# Our options are to either explicitly choose the deprecated
# behavior or switch to the new behavior, both of which
# suppress the warning message. There doesn't seem to be any
# reason not to switch to the new behavior, so we do that here.
I18n.config.enforce_available_locales = true
