class Order < ApplicationRecord
  include ThePayment
  include TheRefund

  belongs_to :payment_strategy, optional: true
  belongs_to :user
  belongs_to :buyer, class_name: '::Buyer', foreign_key: :buyer_id
  has_many :payment_orders, inverse_of: :order, dependent: :destroy
  has_many :payments, through: :payment_orders
  has_many :order_items, dependent: :destroy, autosave: true, inverse_of: :order
  has_many :refunds, dependent: :nullify
  has_many :order_promotes, autosave: true, inverse_of: :order
  has_many :order_serves, autosave: true
  has_many :pure_order_promotes, -> { where(order_item_id: nil) }, class_name: 'OrderPromote'
  has_many :pure_order_serves, -> { where(order_item_id: nil) }, class_name: 'OrderServe'

  accepts_nested_attributes_for :order_items

  scope :credited, -> { where(payment_strategy_id: PaymentStrategy.where.not(period: 0).pluck(:id)) }
  scope :to_pay, -> { where(payment_status: ['unpaid', 'part_paid']) }

  after_initialize if: :new_record? do |o|
    self.uuid = UidHelper.nsec_uuid('OD')
    self.payment_status = 'unpaid'
    self.buyer_id = self.user&.buyer_id
    self.payment_strategy_id = self.buyer&.payment_strategy_id

    cart_item_ids = order_items.map(&:cart_item_id)
    additions = AdditionService.new(cart_item_ids)
    additions.promote_charges.each do |promote_charge|
      self.order_promotes.build(promote_charge_id: promote_charge.id, promote_id: promote_charge.promote_id, amount: promote_charge.subtotal)
    end
    additions.serve_charges.each do |serve_charge|
      self.order_serves.build(serve_charge_id: serve_charge.id, serve_id: serve_charge.serve_id, amount: serve_charge.subtotal)
    end
  end
  before_create :sum_cache

  enum payment_status: {
    unpaid: 0,
    part_paid: 1,
    all_paid: 2,
    refunding: 3,
    refunded: 4
  }

  def migrate_from_cart_items(cart_item_ids)
    cart_items = CartItem.where(id: cart_item_ids)

    user_ids = cart_items.map(&:user_id).uniq
    if user_ids.size > 1
      self.errors.add :user_id, 'Different User for create Order!'
    else
      self.user = User.find_by(id: user_ids.first)
      self.buyer_id = self.user&.buyer_id
    end

    cart_items.each do |cart_item|
      self.order_items.build cart_item_id: cart_item.id, good_type: cart_item.good_type, good_id: cart_item.good_id, quantity: cart_item.quantity
    end
  end

  def promote_amount
    order_promotes.sum(:amount)
  end

  def sum_cache
    self.pure_serve_sum = self.pure_order_serves.sum { |o| o.amount }
    self.pure_promote_sum = self.pure_order_promotes.sum { |o| o.amount }
    self.serve_sum = self.order_serves.sum { |o| o.amount }
    self.promote_sum = self.order_promotes.sum { |o| o.amount }
    self.subtotal = self.order_items.sum { |o| o.amount }
    self.amount = self.subtotal + self.pure_serve_sum + self.pure_promote_sum
    self.order_items.each do |order_item|
      order_item.sum_cache
    end
  end

end
