# Serializes ActiveRecord models for read-only dashboard API responses.
class JsonPresenter
  class << self
    def market_snapshot(snapshot)
      {
        id: snapshot.id,
        symbol: snapshot.symbol,
        timeframe: snapshot.timeframe,
        price: snapshot.price,
        rsi: snapshot.rsi,
        ema50: snapshot.ema50,
        ema200: snapshot.ema200,
        support: snapshot.support,
        resistance: snapshot.resistance,
        created_at: snapshot.created_at.iso8601
      }
    end

    def trade_signal(signal)
      {
        id: signal.id,
        symbol: signal.symbol,
        action: signal.action,
        confidence: signal.confidence,
        timeframe: signal.timeframe,
        reason: signal.reason,
        created_at: signal.created_at.iso8601
      }
    end

    def order(order)
      {
        id: order.id,
        action: order.action,
        entry_type: order.entry_type,
        entry_price: order.entry_price,
        stop_loss: order.stop_loss,
        take_profit: order.take_profit,
        tp_leg: order.tp_leg,
        status: order.status,
        expires_at: order.expires_at&.iso8601,
        created_at: order.created_at.iso8601
      }
    end

    def position(position)
      {
        id: position.id,
        ticket: position.ticket,
        symbol: position.symbol,
        action: position.action,
        entry_price: position.entry_price,
        stop_loss: position.stop_loss,
        take_profit: position.take_profit,
        status: position.status,
        profit_loss: position.profit_loss
      }
    end
  end
end
