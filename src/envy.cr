require "yaml"

require "./envy/version"
require "./envy/*"

module Envy
  extend self

  def from_file(*files, perm : Int32? = nil) : Nil
    load do
      set_perms files, perm

      files.each do |file|
        return from_file(file, force: false) if File.readable?(file)
      end

      raise Error.new("files (#{files.join(", ")}) not found or not readable")
    end
  end

  def from_file!(*files, perm : Int32? = nil) : Nil
    load do
      set_perms files, perm

      files.each do |file|
        return from_file(file, force: true) if File.readable?(file)
      end

      raise Error.new("files (#{files.join(", ")}) not found or not readable")
    end
  end

  private def from_file(file, *, force : Bool) : Nil
    File.open(file) do |file|
      load Hash(YAML::Any, YAML::Any).from_yaml(file), force: force
    end
  end

  private def set_perms(files : Tuple, perm : Int32? = nil) : Nil
    perm = 0o600 if perm.nil?

    files.each do |file|
      File.chmod(file, perm) if File.exists?(file)
    end
  end

  private def load(yaml : Hash, prev_key = "", *, force : Bool) : Nil
    yaml.each do |key, val|
      env_key = "#{prev_key}_#{key}".upcase.lchop('_')

      case raw = val.raw
      when Hash
        load raw, env_key, force: force
      when Array
        raw.each_with_index do |x, i|
          env_key_i = "#{env_key}_#{i}".lchop('_')
          ENV[env_key_i] = x.to_s if force || ENV[env_key_i]?.nil?
        end
      else
        ENV[env_key] = val.to_s if force || ENV[env_key]?.nil?
      end
    end
  end

  private def load(& : Proc(Nil)) : Nil
    unless ENV[var = "ENVY_LOADED"]? == "yes"
      yield
      ENV[var] = "yes"
    end
  rescue err : Exception
    raise Error.new(err.message)
  end
end
