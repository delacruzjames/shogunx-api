module Api
  module V1
    class ExecutionController < BaseController
      def show
        instruction = ExecutionInstructionService.new(format: :execution).call
        render json: instruction
      end
    end
  end
end
