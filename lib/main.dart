import 'package:flutter/material.dart';
import 'dart:async';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';
import 'package:dio/dio.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({Key? key}) : super(key: key);

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  PusherChannelsFlutter pusher = PusherChannelsFlutter.getInstance();

  String _log = 'output:\n';
  String callbackUrlKey = "__Secure-next-auth.callback-url";
  String csrfTokenKey = "__Host-next-auth.csrf-token";
  String sessionTokenKey = "__Secure-next-auth.session-token";


  final _apiKey = TextEditingController();
  final _cluster = TextEditingController();
  final _channelName = TextEditingController();
  final _eventName = TextEditingController();
  final _channelFormKey = GlobalKey<FormState>();
  final _eventFormKey = GlobalKey<FormState>();
  final _listViewController = ScrollController();
  final _data = TextEditingController();

  void log(String text) {
    print("LOG: $text");
    setState(() {
      _log += text + "\n";
      Timer(
          const Duration(milliseconds: 100),
              () => _listViewController
              .jumpTo(_listViewController.position.maxScrollExtent));
    });
  }

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  void onConnectPressed() async {
    if (!_channelFormKey.currentState!.validate()) {
      return;
    }
    // Remove keyboard
    FocusScope.of(context).requestFocus(FocusNode());
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString("apiKey", _apiKey.text);
    prefs.setString("cluster", _cluster.text);
    prefs.setString("channelName", _channelName.text);

    try {
      await pusher.init(
        apiKey: _apiKey.text,
        cluster: _cluster.text,
        onConnectionStateChange: onConnectionStateChange,
        onError: onError,
        onSubscriptionSucceeded: onSubscriptionSucceeded,
        onEvent: onEvent,
        onSubscriptionError: onSubscriptionError,
        onDecryptionFailure: onDecryptionFailure,
        onMemberAdded: onMemberAdded,
        onMemberRemoved: onMemberRemoved,
        onSubscriptionCount: onSubscriptionCount,
        // authEndpoint: "http://localhost:3030/pusher/auth",
        // onAuthorizer: onAuthorizer
      );
      await pusher.subscribe(channelName: _channelName.text);
      await pusher.connect();
    } catch (e) {
      log("ERROR: $e");
    }
  }

  void onConnectionStateChange(dynamic currentState, dynamic previousState) {
    log("Connection: $currentState");
  }

  void onError(String message, int? code, dynamic e) {
    log("onError: $message code: $code exception: $e");
  }

  void onEvent(PusherEvent event) {
    log("onEvent: $event");
  }

  void onSubscriptionSucceeded(String channelName, dynamic data) {
    log("onSubscriptionSucceeded: $channelName data: $data");
    final me = pusher.getChannel(channelName)?.me;
    log("Me: $me");
  }

  void onSubscriptionError(String message, dynamic e) {
    log("onSubscriptionError: $message Exception: $e");
  }

  void onDecryptionFailure(String event, String reason) {
    log("onDecryptionFailure: $event reason: $reason");
  }

  void onMemberAdded(String channelName, PusherMember member) {
    log("onMemberAdded: $channelName user: $member");
  }

  void onMemberRemoved(String channelName, PusherMember member) {
    log("onMemberRemoved: $channelName user: $member");
  }

  void onSubscriptionCount(String channelName, int subscriptionCount) {
    log("onSubscriptionCount: $channelName subscriptionCount: $subscriptionCount");
  }

  dynamic onAuthorizer(String channelName, String socketId, dynamic options) {
    return {
      "auth": "foo:bar",
      "channel_data": '{"user_id": 1}',
      "shared_secret": "foobar"
    };
  }

  void onTriggerEventPressed() async {
    var eventFormValidated = _eventFormKey.currentState!.validate();
    // onSubscriptionCount(_data.text, 1);
    if (!eventFormValidated) {
      return;
    }
    // SharedPreferences prefs = await SharedPreferences.getInstance();
    // prefs.setString("eventName", _eventName.text);
    // prefs.setString("data", _data.text);
    // pusher.trigger(PusherEvent(
    //     channelName: _channelName.text,
    //     eventName: _eventName.text,
    //     data: _data.text));

    login();



  }
  Future<void> storeAuthToken(List<dynamic> authToken) async {
    try {
      //TODO: Use the flutter_secure_storage package instead of Shared Preferences
      SharedPreferences prefs = await SharedPreferences.getInstance();
      List<String> csrfToken = authToken[0].split(";");
      List<String> callbackUrl = authToken[1].split(";");
      List<String> sessionToken = [];

      if (authToken.length == 3) {
        sessionToken = authToken[2].split(";");
      }

      prefs.setString(callbackUrlKey, callbackUrl.first.trim());
      prefs.setString(csrfTokenKey, csrfToken.first.trim());
      prefs.setString(
        sessionTokenKey,
        sessionToken.isNotEmpty ? sessionToken.first.trim() : '',
      );
    } catch (error, stack) {
      debugPrint('$error\n$stack');
      throw {'message': 'Failed to save tokens'};
    }
  }

  Future<String> getAuthToken() async {
    try {
      SharedPreferences prefs = await SharedPreferences.getInstance();
      String? callbackUrl = prefs.getString(callbackUrlKey);
      String? csrfToken = prefs.getString(csrfTokenKey);
      String? sessionToken = prefs.getString(sessionTokenKey);

      String? cookies = "${callbackUrl!}; ${csrfToken!}; ${sessionToken!}";

      return cookies;
    } catch (error, stack) {
      debugPrint('$error\n$stack');
      throw {'message': 'Failed to get tokens'};
    }
  }

  Future<void> login() async {
    try {
      var dio = Dio();
      var response = await dio.post(
        "http://10.0.2.2:3000/api/v1/open/login",
        data: {
          "email":"text+driver@gmail.com",
          "password":"dGVzdFBhc3MxMjM="
        },
      );
      // Handle login success


      print("Login successful: ${response.data}");

      await storeAuthToken(response.data["cookies"]); // Await storeAuthToken
      String accessToken = await getAuthToken();
      print(accessToken);
      // Now you can call the function to send a message
      await sendMessage(accessToken);
    } catch (e) {
      // Handle login failure
      print("Login failed: $e");
    }
  }

  Future<void> sendMessage( String accessToken) async {
    try {
      var dio = Dio();
      // Configure Dio to follow redirects

      var response = await dio.post(
        "http://10.0.2.2:3000/api/v1/pusher/chat-message/insert",
        data: {
          "chat_room_id": "1",
          "sender_id": "clsu5j3bd004nd80v5ykcubfn",
          "message": "Hello This is Sunny-DRIVER",
          "user_type": "DRIVERUSER"
        },
          options: Options(
            headers: {
              'Cookie': accessToken,
            },

          )
      );
      // Handle send message success
      print("Message sent successfully: ${response.data}");
    } catch (e) {
      // Handle send message failure
      print("Failed to send message: $e");
    }
  }



  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      _apiKey.text = prefs.getString("apiKey") ?? '0465a1722741b8ea671b';
      _cluster.text = prefs.getString("cluster") ?? 'ap2';
      _channelName.text = prefs.getString("channelName") ?? 'chat_1';
      _eventName.text = prefs.getString("eventName") ?? 'message';
      _data.text = prefs.getString("data") ?? 'test';
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text(pusher.connectionState == 'DISCONNECTED'
              ? 'Pusher Channels Example'
              : _channelName.text),
        ),
        body: Padding(
          padding: const EdgeInsets.all(8.0),
          child: ListView(
              controller: _listViewController,
              scrollDirection: Axis.vertical,
              shrinkWrap: true,
              children: <Widget>[
                if (pusher.connectionState != 'CONNECTED')
                  Form(
                      key: _channelFormKey,
                      child: Column(children: <Widget>[
                        TextFormField(
                          controller: _apiKey,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your API key.'
                                : null;
                          },
                          decoration:
                          const InputDecoration(labelText: 'API Key'),
                        ),
                        TextFormField(
                          controller: _cluster,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your cluster.'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Cluster',
                          ),
                        ),
                        TextFormField(
                          controller: _channelName,
                          validator: (String? value) {
                            return (value != null && value.isEmpty)
                                ? 'Please enter your channel name.'
                                : null;
                          },
                          decoration: const InputDecoration(
                            labelText: 'Channel',
                          ),
                        ),
                        ElevatedButton(
                          onPressed: onConnectPressed,
                          child: const Text('Connect'),
                        )
                      ]))
                else
                  Form(
                    key: _eventFormKey,
                    child: Column(children: <Widget>[
                      ListView.builder(
                          scrollDirection: Axis.vertical,
                          shrinkWrap: true,
                          itemCount: pusher
                              .channels[_channelName.text]?.members.length,
                          itemBuilder: (context, index) {
                            final member = pusher
                                .channels[_channelName.text]!.members.values
                                .elementAt(index);

                            return ListTile(
                                title: Text(member.userInfo.toString()),
                                subtitle: Text(member.userId));
                          }),
                      TextFormField(
                        controller: _eventName,
                        validator: (String? value) {
                          return (value != null && value.isEmpty)
                              ? 'Please enter your event name.'
                              : null;
                        },
                        decoration: const InputDecoration(
                          labelText: 'Event',
                        ),
                      ),
                      TextFormField(
                        controller: _data,
                        decoration: const InputDecoration(
                          labelText: 'Data',
                        ),
                      ),
                      ElevatedButton(
                        onPressed: onTriggerEventPressed,
                        child: const Text('Trigger Event'),
                      ),
                    ]),
                  ),
                SingleChildScrollView(
                    scrollDirection: Axis.vertical, child: Text(_log)),
              ]),
        ),
      ),
    );
  }
}