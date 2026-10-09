import {createNavigationContainerRef} from '@react-navigation/native';

/**
 * The app's NavigationContainer, for code that drives navigation from outside
 * any screen — the tutorial overlay sits above the navigators and switches tabs
 * as it walks through them.
 */
export const navigationRef = createNavigationContainerRef<any>();
