require 'tdlib-ruby'
require 'pry'

TD.configure do |config|
  config.lib_path = ''

  # You should obtain your own api_id and api_hash from https://my.telegram.org/apps
  config.client.api_id = 
  config.client.api_hash = ''
end

TD::Api.set_log_verbosity_level(1)

@client = TD::Client.new

def print_chat_params(id)
  chat = @client.broadcast_and_receive('@type': 'getChat', 'chat_id': id)
  p "Name #{chat['title']}, ID = #{chat['id']}" if chat['type']['is_channel']
end

begin
  state = nil

  @client.on('updateAuthorizationState') do |update|
    next unless update.dig('authorization_state', '@type') == 'authorizationStateWaitPhoneNumber'
    state = :wait_phone
  end

  @client.on('updateAuthorizationState') do |update|
    next unless update.dig('authorization_state', '@type') == 'authorizationStateWaitCode'
    state = :wait_code
  end

  @client.on('updateAuthorizationState') do |update|
    next unless update.dig('authorization_state', '@type') == 'authorizationStateReady'
    state = :init
  end

  @client.on('updateNewMessage') do |update|
    @channel_ids.include?(update['message']['chat_id'].to_s)
    @client.broadcast('@type' => 'forwardMessages', 'chat_id' => @Me[id], 'from_chat_id' => update['message']['chat_id'], 'message_ids' => [update['message']['id']])  
  end

  loop do
    case state
    when :wait_phone
      p 'Please, enter your phone number:'
      phone = STDIN.gets.strip
      params = {
        '@type' => 'setAuthenticationPhoneNumber',
        'phone_number' => phone
      }
      @client.broadcast_and_receive(params)
    when :wait_code
      p 'Please, enter code from SMS:'
      code = STDIN.gets.strip
      params = {
        '@type' => 'checkAuthenticationCode',
        'code' => code
      }
      @client.broadcast_and_receive(params)
    when :init
      @Me = @client.broadcast_and_receive('@type' => 'getMe')
      сhats = @client.broadcast_and_receive('@type': 'getChats', 'offset_order': 9223372036854775807, 'offset_chat_id': 0, 'limit': 50)
      p 'Список каналов и их ID'
      сhats['chat_ids'].each do |id|
        print_chat_params(id)
      end
      p 'Введите ID необходимых каналов через запятую'
      @channel_ids = STDIN.gets.strip.delete(' ').split(',')
      state = :ready
    end
  end

ensure
  @client.close
end