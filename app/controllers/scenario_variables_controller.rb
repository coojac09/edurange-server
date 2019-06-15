
class ScenarioVariablesController < VariablesController

  def index
    @variables = @scenario.variables
  end

  def new
    @variable = VariableTemplate.new
    @variable.scenario = @scenario
  end

  def create
    @variable = VariableTemplate.new(variable_params)
    logger.debug(@variable.scenario.id)
    if @variable.valid? then
      @variable.save!
      flash[:notice] = "Variable '#{@variable.name}' Added"
      redirect_to action: :index
    else
      render :new
    end
  end

  private

  def find_scenario
    Scenario.find(params.require(:scenario_id))
  end

  before_action def set_instance_variables
    @scenario = find_scenario
    @user = current_user
  end

end

