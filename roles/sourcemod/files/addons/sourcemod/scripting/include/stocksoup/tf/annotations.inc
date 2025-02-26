/**
 * Stocks to create and deal with TF2's rarely-used annotation system.
 */

#if defined __stocksoup_tf_annotations_included
	#endinput
#endif

#define __stocksoup_tf_annotations_included

// Define NULL_SOUND as an empty sound file.
#if !defined NULL_SOUND
	#define NULL_SOUND "vo/null.mp3"
#endif

/**
 * Object-oriented wrapper for TF2's `show_annotation` event.
 */
methodmap TFAnnotationEvent < Event {
	public TFAnnotationEvent() {
		TFAnnotationEvent event = view_as<TFAnnotationEvent>(CreateEvent("show_annotation"));
		
		/**
		 * kludge because we can't use `this` nor call methodmap functions in the body of the
		 * constructor method
		 */
		__TFAnnotationEvent_InitDefaults(event);
		
		return event;
	}
	
	property bool ShowEffect {
		public get() {
			return this.GetBool("show_effect");
		}
		public set(bool bShowEffect) {
			this.SetBool("show_effect", bShowEffect);
		}
	}
	
	property bool ShowDistance {
		public get() {
			return this.GetBool("show_distance");
		}
		public set(bool bShowDistance) {
			this.SetBool("show_distance", bShowDistance);
		}
	}
	
	property int VisibilityBits {
		public get() {
			return this.GetInt("visibilityBitfield");
		}
		public set(int visibilityBitfield) {
			this.SetInt("visibilityBitfield", visibilityBitfield);
		}
	}
	
	property int FollowEntity {
		public get() {
			return this.GetInt("follow_entindex");
		}
		public set(int entity) {
			this.SetInt("follow_entindex", entity);
		}
	}
	
	property int ID {
		public set(int id) {
			this.SetInt("id", id);
		}
	}
	
	property float Lifetime {
		public set(float flLifetime) {
			this.SetFloat("lifetime", flLifetime);
		}
	}
	
	public void SetClientVisibility(int client, bool bVisible = true) {
		if (bVisible) {
			this.VisibilityBits |= 1 << client;
		} else {
			this.VisibilityBits &= ~(1 << client);
		}
	}
	
	public void SetSound(const char[] sound) {
		this.SetString("play_sound", sound);
	}
	
	public void SetPosition(const float vecPosition[3]) {
		this.SetFloat("worldPosX", vecPosition[0]);
		this.SetFloat("worldPosY", vecPosition[1]);
		this.SetFloat("worldPosZ", vecPosition[2]);
	}
	
	public void SetNormal(const float vecNormal[3]) {
		this.SetFloat("worldNormalX", vecNormal[0]);
		this.SetFloat("worldNormalY", vecNormal[1]);
		this.SetFloat("worldNormalZ", vecNormal[2]);
	}
	
	public void SetText(const char[] text) {
		this.SetString("text", text);
	}
	public void GetText(char[] text, int maxlen) {
		this.GetString("text", text, maxlen);
	}
}

/**
 * Internal function to sets sane default values for an annotation event.  We could just call
 * the Event.Set* functions, but I wouldn't want to have to change those in multiple places if
 * the event properties ever change.
 */
static stock void __TFAnnotationEvent_InitDefaults(TFAnnotationEvent annotation) {
	annotation.Lifetime = 5.0;
	annotation.SetSound(NULL_SOUND);
}

/**
 * Hides an annotation by its ID.
 */
stock void TF2_HideAnnotation(int id) {
	Event event = CreateEvent("hide_annotation");
	
	if (event) {
		event.SetInt("id", id);
		event.Fire();
	}
}

/**
 * Creates a basic annotation event for use with `TF2_ShowPositionalAnnotation` or
 * `TF2_ShowFollowerAnnotation`.
 */
static stock TFAnnotationEvent TF2_CreateStockAnnotation(const int[] clients, int numClients,
		const char[] text, int id = 0, const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	TFAnnotationEvent annotation = new TFAnnotationEvent();
	
	if (annotation) {
		int visbits;
		for (int i = 0; i <= numClients; i++) {
			visbits |= 1 << clients[i];
		}
		annotation.VisibilityBits = visbits;
		
		annotation.SetText(text);
		annotation.ID = id;
		annotation.SetSound(sound);
		annotation.Lifetime = lifetime;
	}
	return annotation;
}

/**
 * Displays a positional annotation to a list of clients.
 */
stock void TF2_ShowPositionalAnnotation(const int[] clients, int numClients,
		const float vecPosition[3], const char[] text, int id = 0,
		const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	TFAnnotationEvent annotation = TF2_CreateStockAnnotation(clients, numClients, text, id,
			sound, lifetime);
	
	if (annotation) {
		annotation.SetPosition(vecPosition);
		annotation.Fire();
	}
}

/**
 * Wrapper to display a positional annotation to one client.
 */
stock void TF2_ShowPositionalAnnotationToClient(int client, const float vecPosition[3],
		const char[] text, int id = 0, const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	int clients[1];
	clients[0] = client;
	
	TF2_ShowPositionalAnnotation(clients, 1, vecPosition, text, id, sound, lifetime);
}

/**
 * Wrapper to display a positional annotation to all clients.
 */
stock void TF2_ShowPositionalAnnotationToAll(const float vecPosition[3], const char[] text,
		int id = 0, const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	int[] clients = new int[MaxClients];
	int total = 0;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			clients[total++] = i;
		}
	}
	
	if (!total) {
		return;
	}
	
	TF2_ShowPositionalAnnotation(clients, total, vecPosition, text, id, sound, lifetime);
}

/**
 * Displays an entity-following annotation to a list of clients.
 */
stock void TF2_ShowFollowingAnnotation(const int[] clients, int numClients, int followEntity,
		const char[] text, int id = 0, const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	TFAnnotationEvent annotation = TF2_CreateStockAnnotation(clients, numClients, text, id,
			sound, lifetime);
	
	if (annotation) {
		annotation.FollowEntity = followEntity;
		annotation.Fire();
	}
}

/**
 * Wrapper to display an entity-following annotation to one client.
 */
stock void TF2_ShowFollowingAnnotationToClient(int client, int followEntity,
		const char[] text, int id = 0, const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	int clients[1];
	clients[0] = client;
	
	TF2_ShowFollowingAnnotation(clients, 1, followEntity, text, id, sound, lifetime);
}

/**
 * Wrapper to display an entity-following annotation to all clients.
 */
stock void TF2_ShowFollowingAnnotationToAll(int followEntity, const char[] text, int id = 0,
		const char[] sound = NULL_SOUND, float lifetime = 5.0) {
	int[] clients = new int[MaxClients];
	int total = 0;
	
	for (int i = 1; i <= MaxClients; i++) {
		if (IsClientInGame(i)) {
			clients[total++] = i;
		}
	}
	
	if (!total) {
		return;
	}
	
	TF2_ShowFollowingAnnotation(clients, total, followEntity, text, id, sound, lifetime);
}
