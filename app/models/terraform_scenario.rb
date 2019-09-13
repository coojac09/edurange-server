require 'open3'

class TerraformScenario

  def initialize(scenario)
    @scenario = scenario
  end

  attr_reader :scenario

  def logger
    Rails.logger
  end

  def data_dir
    Rails.root.join('data', 'scenarios', scenario.uuid)
  end

  def source_dir
    scenario.path
  end

  def variables_file
    data_dir.join('variables.auto.tfvars.json')
  end

  def run cmd
    Open3.popen3(cmd, chdir: data_dir) do |stdin, stdout, stderr, p|
      stdout.each do |line|
        logger.debug(line.chop)
      end
      p.value.success?
    end
  end

  def init!
    data_dir.mkdir unless data_dir.exist?
    run "terraform init -no-color #{source_dir}"
  end

  def apply!
    data_dir.mkpath unless data_dir.exist?
    variables_file.write(JSON.pretty_generate(TerraformScenario.serialize_scenario(scenario)))
    run "terraform apply -auto-approve -no-color #{source_dir}"
  end

  def destroy!
    run "terraform destroy -auto-approve -no-color #{source_dir}"
  end

  def output!
    stdout, success = Open3.capture2('terraform output -json -no-color', chdir: data_dir)
    if success then
      output = JSON.parse(stdout)
      logger.debug(output)
      if output['instances'] then
        instances = output["instances"]["value"]
        instances.each do |h|
          i = scenario.instances.find_by_name(h['name'])
          if i then
            i.update!(ip_address_public: h['public_ip'])
          else
            logger.warn("no instance with name #{h['name']}")
          end
        end
      end
    end
  end

  def start!
    scenario.starting!
    if init! && apply! then
      output!
      scenario.started!
    else
      scenario.error!
    end
  rescue
    scenario.error!
    raise
  end

  def stop!
    scenario.stopping!
    if destroy! then
      scenario.stopped!
      scenario.instances.each do |i|
        i.update!(
          ip_address_public: nil
        )
      end
    else
      scenario.error!
    end
  rescue
    scenario.error!
    raise
  end

  def self.serialize_player(player)
    h = {
      login: player.login,
      password: {
        plaintext: player.password,
        hash: player.password_hash
      }
    }
    player.variables.each do |var|
      h.merge!(TerraformScenario.serialize_variable(var))
    end
    h
  end

  def self.serialize_group(group)
    h = {}
    h[group.name.downcase] = group.players.map{|p| TerraformScenario.serialize_player(p) }
    h
  end

  def self.serialize_variable(variable)
    h = Hash.new
    if variable.password? then
      h[variable.name] = {
        plaintext: variable.value,
        hash: UnixCrypt::SHA512.build(variable.value)
      }
    else
      h[variable.name] = variable.value
    end
    h
  end

  def self.serialize_scenario(scenario)
    h = {
      scenario_id: scenario.uuid,
    }
    scenario.variables.each do |v|
      h.merge!(TerraformScenario.serialize_variable(v))
    end
    scenario.groups.each do |g|
      h.merge!(TerraformScenario.serialize_group(g))
    end
    h
  end

end
