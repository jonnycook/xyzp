define ['xyzp/XObject'], (XObject) ->
	class ObservePool extends XObject
		observe: (observable, observer) ->
			@observeObject observable, observer

		# constructor: ->
		# 	super
		# 	@observers = []

		# observe: (observable, observer) ->
		# 	observable.observe observer
		# 	@observers.push observable:observable, observer:observer

		# allStopObserving: ->
		# 	observable.stopObserving observer for {observable:observable, observer:observer} in @observers
		# 	@observers = []

		# destruct: ->
		# 	super
		# 	@allStopObserving()