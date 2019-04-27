using ReactNative;
using ReactNative.Bridge;
using System;
using System.Collections.Generic;
using System.Threading;
using Windows.ApplicationModel.Core;
using Windows.UI.Core;
using Windows.UI.Xaml;
using Newtonsoft.Json.Linq;
using ReactNative.UIManager;

namespace ReactNativeConfig
{
    /// <summary>
    /// A module that allows JS to share data.
    /// </summary>
    partial class ReactNativeConfigModule : NativeModuleBase
    {
        public override string Name
        {
            get { return "ReactNativeConfig"; }
        }

        public string envFor(string key)
        {
            return DOT_ENV[key];
        }

        public override JObject ModuleConstants
        {
            get
            {
                return JObject.FromObject(DOT_ENV);
            }
        }
    }
}

