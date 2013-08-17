module Support::Session
	def get *args
		args[1] ||= {}
		args[2] ||= {'rack.session' => (@session or {})}
		super(*args)
	end

	def post *args
		args[1] ||= {}
		args[2] ||= {'rack.session' => (@session or {})}
		super(*args)
	end

	def put *args
		args[1] ||= {}
		args[2] ||= {'rack.session' => (@session or {})}
		super(*args)
	end
end
