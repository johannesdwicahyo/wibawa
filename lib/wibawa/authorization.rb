module Wibawa
  # Authorization adapters. Each answers `authorized?(action, subject)` and
  # `scope(relation)`. Actions are :index, :show, :new, :create, :edit, :update,
  # :destroy, :export, :"batch_<name>" and member action names.
  module Authorization
    def self.build(user)
      setting = Wibawa.config.authorization
      case setting
      when nil, false then Allow.new(user)
      when :pundit then PunditAdapter.new(user)
      when :action_policy then ActionPolicyAdapter.new(user)
      when Proc then ProcAdapter.new(user, setting)
      when Class then setting.new(user)
      when String then Object.const_get(setting).new(user)
      else raise Error, "Unknown Wibawa authorization setting: #{setting.inspect}"
      end
    end

    # For batch and member actions without their own policy method, fall back
    # to a sensible CRUD permission.
    def self.fallback_for(action)
      name = action.to_s
      return :index if name == "export"
      return :destroy if name == "batch_destroy"
      return :update if name.start_with?("batch_")
      return :create if name == "new"
      return :update if name == "edit"

      :update
    end

    class Allow
      attr_reader :user

      def initialize(user)
        @user = user
      end

      def authorized?(_action, _subject) = true
      def scope(relation) = relation
    end

    class ProcAdapter < Allow
      def initialize(user, callable)
        super(user)
        @callable = callable
      end

      def authorized?(action, subject)
        !!@callable.call(user, action.to_sym, subject)
      end
    end

    class PunditAdapter < Allow
      def authorized?(action, subject)
        policy = ::Pundit.policy!(user, subject)
        query = "#{action}?"
        query = "#{Authorization.fallback_for(action)}?" unless policy.respond_to?(query)
        !!policy.public_send(query)
      end

      def scope(relation)
        ::Pundit.policy_scope!(user, relation)
      end
    end

    class ActionPolicyAdapter < Allow
      def authorized?(action, subject)
        policy = ::ActionPolicy.lookup(subject).new(subject, user: user)
        rule = :"#{action}?"
        rule = :"#{Authorization.fallback_for(action)}?" unless policy.respond_to?(rule)
        policy.apply(rule)
      end

      def scope(relation)
        policy = ::ActionPolicy.lookup(relation.klass).new(nil, user: user)
        policy.apply_scope(relation, type: :active_record_relation)
      rescue ::ActionPolicy::UnknownScopeType, ::ActionPolicy::UnknownNamedScope
        relation
      end
    end
  end
end
