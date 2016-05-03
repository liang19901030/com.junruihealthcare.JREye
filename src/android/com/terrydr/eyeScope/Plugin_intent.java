package com.terrydr.eyeScope;

import org.apache.cordova.CallbackContext;
import org.apache.cordova.CordovaPlugin;
import org.apache.cordova.PluginResult;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;

import android.content.Intent;
import android.os.Bundle;
import android.util.Log;
import android.widget.Toast;

public class Plugin_intent extends CordovaPlugin {
	private final static String TAG = "Plugin_intent";
	private String infos;

	public Plugin_intent() {
	}

	CallbackContext callbackContext;

	@Override
	public boolean execute(String action, org.json.JSONArray args,
			CallbackContext callbackContext) throws org.json.JSONException {
		this.callbackContext = callbackContext;
		if (action.equals("jrEyeTakePhotos")) {
			Log.e(TAG, "jrEyeTakePhotos:" + callbackContext);
			this.startCameraActivity();
			return true;
		} else if (action.equals("jrEyeSelectPhotos")) { // 相册缩略图界面
			Log.e(TAG, "jrEyeSelectPhotos:" + callbackContext);
			startAlbumAty();
			return true;
		} else if (action.equals("jrEyeScanPhotos")) { // 大图片预览界面参数{data:[图片路径，图片路径]}
			Log.e(TAG, "jrEyeScanPhotos:" + callbackContext);
			infos = args.getString(0);
			this.startAlbumItemAty(infos);
			return true;
		}
		return true;

	}

	/**
	 * 跳转到拍照界面 返回参数{leftEye:[];rightEye:[]}
	 */
	private void startCameraActivity() {
		Intent intent = new Intent(cordova.getActivity(), CameraActivity.class);
		cordova.startActivityForResult((CordovaPlugin) this, intent, 0);
	}

	/**
	 * 跳转到相册缩略图界面
	 */
	private void startAlbumAty() {
		Log.e(TAG, "startAlbumAty");
		Intent intent = new Intent(cordova.getActivity(), AlbumAty.class);
		cordova.getActivity().startActivity(intent);
	}

	/**
	 * 大图片预览界面 参数{data:[图片路径，图片路径]}
	 */
	private void startAlbumItemAty(String args) {
		// cordova.getActivity() 获取当前activity的this
		Log.e(TAG, "startAlbumItemAty:" + args);
		Intent intent = new Intent(cordova.getActivity(),
				AlbumItemAtyForJs.class);
		Bundle bundle = new Bundle();
		bundle.putString("data", args);
		intent.putExtras(bundle);
		cordova.startActivityForResult((CordovaPlugin) this, intent, 0);
	}

	public void jrEyeTakePhotos(String result) {
		callbackContext.success(result);
	}

	@Override
	public void onActivityResult(int requestCode, int resultCode, Intent intent) {

		super.onActivityResult(requestCode, resultCode, intent);
		switch (resultCode) { // resultCode为回传的标记，回传的是RESULT_OK
		case 0:
			Log.e(TAG, "r1111111:");
			break;
		case 5:
			Bundle b = intent.getExtras();
			String result_Json = b.getString("result_Json");
			Log.e(TAG, "result_Json String:" + result_Json);
			// PluginResult mPlugin = new PluginResult(PluginResult.Status.OK,
			// result_Json);
			// mPlugin.setKeepCallback(true);
			// callbackContext.sendPluginResult(mPlugin);
			org.json.JSONObject result = null;
			try {
				result = new org.json.JSONObject(result_Json);
				Log.e(TAG, "result:" + result);
			} catch (JSONException e) {
				Log.e(TAG, "String to Json error!");
			}
			Log.e(TAG, "callbackContext:" + callbackContext);
			callbackContext.success(result);
			break;
		default:
			break;
		}
	}
}