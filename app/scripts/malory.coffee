malory = (config) ->
  # Private
  machinations = {}
  workers = {}
  budgetedWorkers = 50

  sendMessage = (worker, message) ->
    new Promise (resolve, reject) ->
      listen = (e) ->
        if (e.data.demand == message.demand)
          e.currentTarget.removeEventListener("message", listen)
          resolve e.data
      worker.addEventListener("message", listen)
      worker.postMessage(message)

  initializeWorker = (configEntry) ->
    worker = new Worker(configEntry.workerUrl)
    workers[configEntry.name + '-' + configEntry.counter] = worker
    message =
      counter: configEntry.counter
      demand: configEntry.initialDemand
      workerArguments: configEntry.workerArguments
    sendMessage(worker, message).then (data) ->
      if data[configEntry.officiallyOutOfMemory]
        configEntry.counter++
        configEntry.workerArguments = data.workerArguments
        initializeWorker(configEntry) unless configEntry.counter > configEntry.budgetWorkers
  
  initializeAllWorkers = (config) ->
    for configEntry, i in config
      configEntry.name = i unless configEntry.name
      configEntry.budgetedWorkers = budgetedWorkers unless configEntry.budgetedWorkers
      configEntry.counter = 0
      initializeWorker configEntry

  # Send message to all workers, returns a promise, which will return an arqray containg each workers response as the index values
  machinations.demand = (demand, workerArguments) ->
    promiseArray = []
    for key, worker of workers
      message =
        demand: demand
        workerArguments: workerArguments
      promiseArray.push sendMessage(worker,message)
    Promise.all(promiseArray)
  
  initializeAllWorkers config

  return machinations