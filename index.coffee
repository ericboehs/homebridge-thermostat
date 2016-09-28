Service = undefined
Characteristic = undefined
request = require('request')

Thermostat = (log, config) ->
  @log = log
  @name = config.name
  @device_id = config.device_id or 'device_id'
  @apiroute = "#{config.api_route}/#{@device_id}"
  @access_token = config.access_token or 'access_token'
  @log @name, @apiroute

  # Characteristic.TemperatureDisplayUnits.CELSIUS = 0;
  # Characteristic.TemperatureDisplayUnits.FAHRENHEIT = 1;
  @temperatureDisplayUnits = Characteristic.TemperatureDisplayUnits.FAHRENHEIT

  @temperature = 24
  # @relativeHumidity = 0.70

  # The value property of CurrentHeatingCoolingState must be one of the following:
  # Characteristic.CurrentHeatingCoolingState.OFF = 0;
  # Characteristic.CurrentHeatingCoolingState.HEAT = 1;
  # Characteristic.CurrentHeatingCoolingState.COOL = 2;
  @currentHeatingCoolingState = Characteristic.CurrentHeatingCoolingState.OFF

  @targetTemperature = 24
  # @targetRelativeHumidity = 0.5
  # @heatingThresholdTemperature = 25
  # @coolingThresholdTemperature = 5

  # The value property of TargetHeatingCoolingState must be one of the following:
  # Characteristic.TargetHeatingCoolingState.OFF = 0;
  # Characteristic.TargetHeatingCoolingState.HEAT = 1;
  # Characteristic.TargetHeatingCoolingState.COOL = 2;
  # Characteristic.TargetHeatingCoolingState.AUTO = 3;
  @targetHeatingCoolingState = Characteristic.TargetHeatingCoolingState.OFF

module.exports = (homebridge) ->
  Service = homebridge.hap.Service
  Characteristic = homebridge.hap.Characteristic
  homebridge.registerAccessory 'homebridge-thermostat', 'Thermostat', Thermostat

Thermostat.prototype =
  cToF: (value) ->
    Number (9 * value / 5 + 32).toFixed(0)

  fToC: (value) ->
    Number (5 * (value - 32) / 9).toFixed(2)

  httpRequest: (url, body, method, username, password, sendimmediately, callback) ->
    request {
      url: url
      body: body
      method: method
      auth:
        user: username
        pass: password
        sendImmediately: sendimmediately
    }, (error, response, body) ->
      callback error, response, body

  identify: (callback) ->
    @log 'Identify requested!'
    callback null

  getCurrentHeatingCoolingState: (callback) ->
    @log 'getCurrentHeatingCoolingState from:', @apiroute + '/info'
    request.get { url: @apiroute + '/info', auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log 'response success'
        json = JSON.parse(body)
        json = JSON.parse(json['result'])

        # { "mode": "cool", "heatWait": 0, "coolWait": 0, "fanState": true, "coolState": false,
        # "heatState": false, "heatLastOn": 1474826798, "coolLastOn": 1475072038, "rawTemperature": 2928,
        # "temperature": 73, "targetTemperature": 74 }

        @log 'Cool, Heat state is %s, %s', json.coolState, json.heatState

        @currentHeatingCoolingState = Characteristic.CurrentHeatingCoolingState.OFF
        if json.coolState
          @currentHeatingCoolingState = Characteristic.CurrentHeatingCoolingState.COOL
        if json.heatState
          @currentHeatingCoolingState = Characteristic.CurrentHeatingCoolingState.HEAT
        callback null, @currentHeatingCoolingState
        # success
      else
        @log 'Error getting state: %s', err
        callback "Error getting state: #{err}"
    ).bind(this)

  getTargetHeatingCoolingState: (callback) ->
    @log 'getTargetHeatingCoolingState from:', @apiroute + '/info'
    request.get { url: @apiroute + '/info', auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log 'response success'
        json = JSON.parse(body)
        json = JSON.parse(json['result'])

        # { "mode": "cool", "heatWait": 0, "coolWait": 0, "fanState": true, "coolState": false,
        # "heatState": false, "heatLastOn": 1474826798, "coolLastOn": 1475072038, "rawTemperature": 2928,
        # "temperature": 73, "targetTemperature": 74 }

        @log 'CoolHeat state is %s', json.mode
        switch json.mode
          when 'off'
            @targetHeatingCoolingState = Characteristic.TargetHeatingCoolingState.OFF
          when 'heat'
            @targetHeatingCoolingState = Characteristic.TargetHeatingCoolingState.HEAT
          when 'cool'
            @targetHeatingCoolingState = Characteristic.TargetHeatingCoolingState.COOL
          # when 'COMFORT_MINUS_ONE'
          #   @targetHeatingCoolingState = Characteristic.TargetHeatingCoolingState.AUTO
          else
            @log 'Not handled case:', json.mode
            err = 'AUTO not supported'
            break
        callback err, @targetHeatingCoolingState
        # success
      else
        @log 'Error getting state: %s', err
        callback "Error getting state: #{err}"
    ).bind(this)

  setTargetHeatingCoolingState: (value, callback) ->
    @log 'setTargetHeatingCoolingState from/to:', @targetHeatingCoolingState, value
    arg = undefined
    switch value
      when Characteristic.TargetHeatingCoolingState.OFF
        arg = 'off'
      when Characteristic.TargetHeatingCoolingState.HEAT
        arg = 'heat'
      when Characteristic.TargetHeatingCoolingState.COOL
        arg = 'cool'
      when Characteristic.TargetHeatingCoolingState.AUTO
        @log 'AUTO state unsupported'
        return callback 'AUTO state unsupported'
      else
        @log 'Not handled case:', value
        return callback "#{value} state unsupported"
        break

    @targetHeatingCoolingState = value

    request.post { url: @apiroute + '/setMode', form: { arg: arg }, auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log JSON.parse body
        @log 'response success'
        callback null
        # success
      else
        @log 'Error setting state: %s', err
        callback "Error setting mode: #{err}"
    ).bind(this)

  getCurrentTemperature: (callback) ->
    @log 'getCurrentTemperature from:', @apiroute + '/info'
    request.get { url: @apiroute + '/info', auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log 'response success'
        json = JSON.parse(body)
        json = JSON.parse(json['result'])

        # { "mode": "cool", "heatWait": 0, "coolWait": 0, "fanState": true, "coolState": false,
        # "heatState": false, "heatLastOn": 1474826798, "coolLastOn": 1475072038, "rawTemperature": 2928,
        # "temperature": 73, "targetTemperature": 74 }
        @log 'Currente Temperature is %s (%s)', json.temperature, json.mode
        @temperature = @fToC parseFloat(json.temperature)
        callback null, @temperature
        # success
      else
        @log 'Error getting current temp: %s', err
        callback "Error getting current temp: #{err}"
    ).bind(this)

  getTargetTemperature: (callback) ->
    @log 'getCurrentTemperature from:', @apiroute + '/info'
    request.get { url: @apiroute + '/info', auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log 'response success'
        json = JSON.parse(body)
        json = JSON.parse(json['result'])

        # { "mode": "cool", "heatWait": 0, "coolWait": 0, "fanState": true, "coolState": false,
        # "heatState": false, "heatLastOn": 1474826798, "coolLastOn": 1475072038, "rawTemperature": 2928,
        # "temperature": 73, "targetTemperature": 74 }
        @log 'Target temperature is %s', json.targetTemperature
        @targetTemperature = @fToC parseFloat(json.targetTemperature)
        callback null, @targetTemperature
        # success
      else
        @log 'Error getting target temp: %s', err
        callback "Error getting target temp: #{err}"
    ).bind(this)

  setTargetTemperature: (value, callback) ->
    @log 'setTargetTemperature from:', @apiroute + '/targetTemperature/' + @cToF value
    request.post { url: @apiroute + '/targetTemp', form: { arg: @cToF value }, auth: { bearer: @access_token } }, ((err, response, body) ->
      if !err and response.statusCode == 200
        @log 'response success'
        callback null
        # success
      else
        @log 'Error getting state: %s', err
        callback "Error setting target temp: #{err}"
    ).bind(this)

  getTemperatureDisplayUnits: (callback) ->
    @log 'getTemperatureDisplayUnits:', @temperatureDisplayUnits
    error = null
    callback error, @temperatureDisplayUnits

  setTemperatureDisplayUnits: (value, callback) ->
    @log 'setTemperatureDisplayUnits from %s to %s', @temperatureDisplayUnits, value
    # @temperatureDisplayUnits = value
    error = null
    error = "Setting display units is not supported"
    callback error

  getCurrentRelativeHumidity: (callback) ->
    @log 'getCurrentRelativeHumidity from:', @apiroute + '/info'
    # request.get { url: @apiroute + '/info' }, ((err, response, body) ->
    #   if !err and response.statusCode == 200
    #     @log 'response success'
    #     json = JSON.parse(body)
    #     #{"state":"OFF","stateCode":5,"temperature":"18.10","humidity":"34.10"}
    #     @log 'Humidity state is %s (%s)', json.state, json.humidity
    #     @relativeHumidity = parseFloat(json.humidity)
    #     callback null, @relativeHumidity
    #     # success
    #   else
    #     @log 'Error getting state: %s', err
    callback "Relative humidity not supported"
    # ).bind(this)

  getTargetRelativeHumidity: (callback) ->
    @log 'Get humidity unsupported'
    error = "Get humidity unsupported"
    callback error

  setTargetRelativeHumidity: (value, callback) ->
    @log 'Set humidity unsupported'
    error = "Set humidity unsupported"
    callback error

  # getHeatingThresholdTemperature: (callback) ->
  #   @log 'Get Heating Threshold unsupported'
  #   error = "Get Heating Threshold unsupported"
  #   callback error

  getName: (callback) ->
    @log 'getName :', @name
    error = null
    callback error, @name

  # You can optionally create an information service if you wish to override
  # the default values for things like serial number, model, etc.
  getServices: ->
    informationService = new (Service.AccessoryInformation)

    informationService
      .setCharacteristic(Characteristic.Manufacturer, 'HTTP Manufacturer')
      .setCharacteristic(Characteristic.Model, 'HTTP Model')
      .setCharacteristic(Characteristic.SerialNumber, 'HTTP Serial Number')

    thermostatService = new (Service.Thermostat)(@name)

    # Required Characteristics
    thermostatService.getCharacteristic(Characteristic.CurrentHeatingCoolingState)
      .on('get', @getCurrentHeatingCoolingState.bind(this))
    thermostatService.getCharacteristic(Characteristic.TargetHeatingCoolingState)
      .on('get', @getTargetHeatingCoolingState.bind(this))
      .on('set', @setTargetHeatingCoolingState.bind(this))
    thermostatService.getCharacteristic(Characteristic.CurrentTemperature)
      .on('get', @getCurrentTemperature.bind(this))
    thermostatService.getCharacteristic(Characteristic.TargetTemperature)
      .on('get', @getTargetTemperature.bind(this))
      .on('set', @setTargetTemperature.bind(this))
    thermostatService.getCharacteristic(Characteristic.TemperatureDisplayUnits)
      .on('get', @getTemperatureDisplayUnits.bind(this))
      .on('set', @setTemperatureDisplayUnits.bind(this))

    unit = Characteristic.TemperatureDisplayUnits.FAHRENHEIT
    thermostatService.getCharacteristic(Characteristic.TemperatureDisplayUnits).value = unit
    thermostatService.getCharacteristic(Characteristic.CurrentTemperature).unit = unit
    thermostatService.getCharacteristic(Characteristic.TargetTemperature).unit = unit

    # Optional Characteristics
    # thermostatService.getCharacteristic(Characteristic.CurrentRelativeHumidity)
    #   .on('get', @getCurrentRelativeHumidity.bind(this))
    # thermostatService.getCharacteristic(Characteristic.TargetRelativeHumidity)
    #   .on('get', @getTargetRelativeHumidity.bind(this))
    #   .on('set', @setTargetRelativeHumidity.bind(this))

    ###
    thermostatService
    	.getCharacteristic(Characteristic.CoolingThresholdTemperature)
    	.on('get', this.getCoolingThresholdTemperature.bind(this));
    ###

    # thermostatService.getCharacteristic(Characteristic.HeatingThresholdTemperature)
    #   .on('get', @getHeatingThresholdTemperature.bind(this))
    thermostatService.getCharacteristic(Characteristic.Name)
      .on('get', @getName.bind(this))

    [
      informationService
      thermostatService
    ]
