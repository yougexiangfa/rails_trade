module Trade
  class My::OrdersController < My::BaseController
    before_action :set_order, only: [
      :show, :edit, :update, :refund, :payment_types, :edit_payment_type, :wait, :destroy,
      :paypal_pay, :stripe_pay, :alipay_pay, :paypal_execute, :wxpay_pay, :wxpay_pc_pay
    ]

    def index
      q_params = {}
      q_params.merge! default_params
      q_params.merge! params.permit(:id, :payment_type, :payment_status)

      @orders = current_user.orders.default_where(q_params).order(id: :desc).page(params[:page])
    end

    def new
      @order = current_cart.orders.build
    end

    def refresh
      @order = current_cart.orders.build(myself: true)
      @order.assign_attributes order_params
    end

    def create
      @order = current_cart.orders.build(order_params)

      if @order.save
        render 'create'
      else
        render :new, locals: { model: @order }, status: :unprocessable_entity
      end
    end

    def direct
      @order = current_buyer.orders.build(order_params)

      if @order.save

      else

      end
    end

    def show
    end

    # todo part paid case
    def wait
      if @order.all_paid?
        render 'show'
      else
        render 'wait'
      end
    end

    def edit
    end

    def update
      @order.assign_attributes(order_params)

      if @order.save
        render 'update'
      else
        render :edit, locals: { model: @order }, status: :unprocessable_entity
      end
    end

    def payment_types

    end

    def edit_payment_type
    end

    def stripe_pay
      if @order.payment_status != 'all_paid'
        @order.stripe_charge(params)
      end

      if @order.errors.blank?
        render 'create', locals: { return_to: @order.approve_url }
      else
        render 'create', locals: { return_to: board_orders_url }
      end
    end

    def alipay_pay
      if @order.payment_status != 'all_paid'
        render 'create', locals: { return_to: @order.alipay_prepay_url }
      else
        render 'create', locals: { return_to: board_orders_url }
      end
    end

    def paypal_pay
      if @order.payment_status != 'all_paid'
        result = @order.paypal_prepay
        render 'create', locals: { return_to: result }
      else
        render 'create', locals: { return_to: board_orders_url }
      end
    end

    def paypal_execute
      if @order.paypal_execute(params)
        flase.now[:notice] = "Order[#{@order.uuid}] placed successfully"
        render 'create', locals: { return_to: board_order_url(@order) }
      else
        flase.now[:notice] =  @order.error.inspect
        render 'create', locals: { return_to: board_orders_url }
      end
    end

    # https://pay.weixin.qq.com/wiki/doc/api/native.php?chapter=6_5
    # 二维码有效期为2小时
    def wxpay_pc_pay
      @wxpay_order = @order.native_order(app: current_wechat_app)

      if @wxpay_order['code'].present? || @wxpay_order.blank?
        render 'wxpay_pay_err'
      else
        file = QrcodeHelper.code_file @wxpay_order['code_url']
        @blob = ActiveStorage::Blob.build_after_upload io: file, filename: "#{@order.id}"
        if @blob.save
          @image_url = @blob.url
          render 'wxpay_pc_pay'
        else
          render 'wxpay_pay_err'
        end
      end
    end

    def wxpay_pay
      @wxpay_order = @order.wxpay_order(app: current_wechat_app)

      if @wxpay_order['code'].present? || @wxpay_order.blank?
        render 'wxpay_pay_err'
      else
        render 'wxpay_pay'
      end
    end

    def refund
      @order.apply_for_refund
    end

    def destroy
      @order.destroy
    end

    private
    def set_order
      @order = Order.find(params[:id])
    end

    def order_params
      params.fetch(:order, {}).permit(
        :quantity,
        :payment_id,
        :payment_type,
        :address_id,
        :invoice_address_id,
        :note
      )
    end

  end
end
