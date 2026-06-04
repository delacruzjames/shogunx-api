module Api
  module V1
    class OrdersController < BaseController
      include ListScoped

      def index
        scope = Order.order(created_at: :desc)
        scope = scope.where(status: params[:status]) if params[:status].present?

        result = paginate(scope)
        render json: {
          data: result[:records].map { |order| JsonPresenter.order(order) },
          meta: result[:meta]
        }
      end
    end
  end
end
