module Spree
  Payment.class_eval do
    def method_alipay?
      payment_method.kind_of? Spree::Gateway::AlipayBase
    end

    # walk around gateway purchase.
    # order/payments, payment/processing
    # order.process_payments!  => payment.process!  => handle_payment_preconditions { process_purchase }
    def handle_payment_preconditions(&block)
      unless block_given?
        raise ArgumentError.new("handle_payment_preconditions must be called with a block")
      end

      if payment_method && payment_method.source_required?
        if source
          if !processing?
            if payment_method.supports?(source) || token_based?
              yield
            else
              invalidate!
              raise Core::GatewayError.new(Spree.t(:payment_method_not_supported))
            end
          end
        elsif method_alipay? # continue to complete alipay payment.
          yield
        else
          raise Core::GatewayError.new(Spree.t(:payment_processing_failed))
        end
      elsif payment_method.is_a?(Spree::Gateway::AlipayDirect)
        yield
      end
    end

    def process_purchase
      started_processing!

      # Only for AlipayDirect
      if payment_method.is_a?(Spree::Gateway::AlipayDirect)
        if(response_code.split(',').last == 'TRADE_SUCCESS')
          complete!
        else
          failure
          gateway_error({response_code: response_code})
        end
      else
        result = gateway_action(source, :purchase, :complete)
      end
      # This won't be called if gateway_action raises a GatewayError
      capture_events.create!(amount: amount)
    end
  end
end
