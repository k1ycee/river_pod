import '../builders.dart';
import '../common.dart';
import '../framework/framework.dart';
import '../state_notifier_provider/state_notifier_provider.dart';
import '../stream_provider/stream_provider.dart';

part 'auto_dispose_provider.dart';

/// The state to a [Provider].
abstract class ProviderDependency<T> extends ProviderDependencyBase {
  /// The value exposed by [Provider].
  ///
  /// It is guaranteed to never change.
  T get value;
}

// ignore: public_member_api_docs
class ProviderDependencyImpl<T> implements ProviderDependency<T> {
  // ignore: public_member_api_docs
  ProviderDependencyImpl(this.value);

  @override
  final T value;
}

/// A provider that exposes a read-only value.
///
/// ## What is a provider
///
/// Providers are the most important components of `Riverpod`. In short, you can think
/// of providers as an access point to a **shared state**.
///
/// Providers solve the following problems:
///
/// - Providers have the flexibility of global variables, without their downsides.\
///   Providers can be accessed from anywhere, while ensuring testability and scalability.
///
/// - Providers are safe to use.\
///   As opposed to most existing solutions, using a provider, it is not possible to
///   read a value in an uninitialized state.\
///   If we can write the code to read a state, that state is available and ready.
///   Even if loaded asynchronously.
///
/// - Providers allow easily and efficiently listening to a piece of state.\
///   They can be accessed in a single line of code, and offers many way to optimize
///   your application.
///
/// ## Creating a provider
///
/// Providers come in many variants, but they all work the same way.
///
/// The most common usage is to declare them as global variables like so:
///
/// ```dart
/// final myProvider = Provider((ref) {
///   return MyValue();
/// });
/// ```
///
/// **NOTE**
/// You do not have to declare providers as globals. It is simply usually the most
/// logical choice.
///
///
/// This snippet consist of three components:
///
/// - `final myProvider`, the declaration of a variable.\
///   This variable is what we will use in the future to read the state of our provider.
///   It should always be immutable.
///
/// - `Provider`, the provider that we decided to use.\
///   [Provider] is the most basic of all providers. It exposes an object that never
///   changes.\
///   We could replace [Provider] with other providers like [StreamProvider] or
///   [StateNotifierProvider], to change how the value is interacted with.
///
/// - A function that creates the shared state.\
///   That function will always receive an object called `ref` as a parameter. This object
///   allows us to read other providers or to perform some operations when the state
///   of our provider will be destroyed.
///
/// The type of the object created by the function passed to a provider depends on
/// the provider used.\
/// For example, the function of a [Provider] can create any object.
/// On the other hand, [StreamProvider]'s callback will be expected to return a [Stream].
///
/// **NOTE**:
/// You can declare as many providers as you, want without limitations.\
/// As opposed to when using `package:provider`, in `Riverpod` we can have two
/// providers expose a state of the same "type":
///
/// ```dart
/// final cityProvider = Provider((ref) => 'London');
/// final countryProvider = Provider((ref) => 'England');
/// ```
///
/// The fact that both providers creates a `String` does not cause conflicts. We will be
/// able to read both values independently from each other without issue.
///
///
/// **WARNING**
/// For providers to work, you have to add `ProviderScope` at the root of your
/// Flutter applications:
///
/// ```dart
/// void main() {
///   runApp(ProviderScope(child: MyApp()));
/// }
/// ```
///
/// ## Combining providers
///
/// We've previously seen how to create a simple provider. But the reality is,
/// in many situation a provider will want to read the state of another provider.
///
/// To do that, we can use the `ref` object passed to the callback of our provider,
/// and use its `read` method.
///
/// As an example, consider the following provider:
///
/// ```dart
/// final cityProvider = Provider((ref) => 'London');
/// ```
///
/// We can now create another provider that will consume our `cityProvider`:
///
/// ```dart
/// final weatherProvider = FutureProvider((ref) async {
///   // We use `ref.read` to read another provider, and we pass it the provider
///   // that we want to consume. Here: cityProvider
///   final city = ref.read(cityProvider);
///
///   // We can then use the result to do something based on the value of `cityProvider`.
///   return fetchWeather(city: city);
/// });
/// ```
///
/// That's it. We've created a provider that depends on another provider.
///
/// ### Creating an object that depends on a lot of providers.
///
/// Sometimes, we may want to create an object that depends on a lot of providers
/// like so:
///
/// ```dart
/// final cityProvider = Provider((ref) => 'London');
/// final countryProvider = Provider((ref) => 'England');
///
/// final weatherProvider = Provider((ref) {
///   final city = ref.read(cityProvider);
///   final country = ref.read(countryProvider);
///
///   return Location(city: city, country: country);
/// });
///
/// class Location {
///   Location({this.city, this.country});
///
///   final String city;
///   final String country;
///
///   String get label => '$city ($country)';
/// }
/// ```
///
/// This can quickly become tedious.
///
/// In that situation, it may be reasonable to pass the `ref` variable to our
/// object directly:
///
/// ```dart
/// final cityProvider = Provider((ref) => 'London');
/// final countryProvider = Provider((ref) => 'England');
///
/// final weatherProvider = Provider((ref) {
///   // Pass the `ref` object to our `Location` class.
///   // `Location` will then be able to call `ref.read` to read the providers.
///   return Location(ref);
/// });
///
/// class Location {
///   Location(this._ref);
///
///   final ProviderReference _ref;
///
///   String get label {
///     final city = _ref.read(cityProvider);
///     final country = _ref.read(countryProvider);
///     return '$city ($country)';
///   }
/// }
/// ```
///
/// This avoids having to implement a constructor, which makes changes on the object
/// easier.
///
/// This is fine as, as opposed to `BuildContext` from Flutter, that `ref` object
/// is completely independent from Flutter/the UI.\
/// As such the object can still be shared and tested.
///
/// ## Disposing the resources the state is destroyed
///
/// During the lifetime of an application, the state associated with a provider may
/// get destroyed.\
/// In this situation, we may want to perform a clean-up before the state destruction.
///
/// This is done by using the `ref` object that is passed to the callback of all providers.
///
/// That `ref` object expose an `onDispose` method, which can be used to listen to
/// the state destruction even to perform some task.
///
/// The following example uses `ref.onDispose` to close a `StreamController`:
///
/// ```dart
/// final example = StreamProvider((ref) {
///   final streamController = StreamController<int>();
///
///   ref.onDispose(() {
///     // Closes the StreamController when the state of this provider is destroyed.
///     streamController.close();
///   });
///
///   return streamController.stream;
/// });
/// ```
class Provider<T> extends AlwaysAliveProviderBase<ProviderDependency<T>, T> {
  /// Creates an immutable value.
  Provider(this._create, {String name}) : super(name);

  /// {@macro riverpod.family}
  static const family = ProviderFamilyBuilder();

  /// {@macro riverpod.autoDispose}
  static const autoDispose = AutoDisposeProviderBuilder();

  final Create<T, ProviderReference> _create;

  @override
  ProviderState<T> createState() => ProviderState();
}

/// The internal state of a [Provider].
class ProviderState<T>
    extends ProviderStateBase<ProviderDependency<T>, T, Provider<T>> {
  @override
  T state;

  @override
  void initState() {
    // ignore: invalid_use_of_visible_for_testing_member
    state = provider._create(ProviderReference(this));
  }

  @override
  ProviderDependency<T> createProviderDependency() {
    return ProviderDependencyImpl(state);
  }
}

/// A family of [Provider].
class ProviderFamily<Result, A> extends Family<Provider<Result>, A> {
  /// Creates a value from an external parameter
  ProviderFamily(Result Function(ProviderReference ref, A a) create)
      : super((a) => Provider((ref) => create(ref, a)));

  /// Overrides the behavior of a family for a part of the application.
  Override overrideAs(
    Result Function(ProviderReference ref, A value) override,
  ) {
    return FamilyOverride(
      this,
      (value) => Provider<Result>((ref) => override(ref, value as A)),
    );
  }
}
