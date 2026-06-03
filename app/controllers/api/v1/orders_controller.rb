module Api
  module V1
    class OrdersController < BaseController
      include ListScoped

      def index
        scope = Order.order(created_at: :desc)
        scope = scope.where(status: params[:status]) if params[:status].present?

        orders = scope.limit(list_limit)
        render json: { data: orders.map { |order| JsonPresenter.order(order) } }
      end
    end
  end
end
