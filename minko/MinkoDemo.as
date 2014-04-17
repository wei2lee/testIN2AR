package  
{
    import aerys.minko.render.Viewport;
    import aerys.minko.scene.node.camera.Camera;
    import aerys.minko.scene.node.Scene;
    import com.in2ar.calibration.IntrinsicParameters;
    import com.in2ar.detect.IN2ARReference;
    import com.in2ar.event.IN2ARDetectionEvent;
    import com.in2ar.minko.MinkoCameraController;
    import com.in2ar.minko.MinkoCaptureMesh;
    import com.in2ar.minko.MinkoContainer;
    import flash.display.BitmapData;
    import flash.events.Event;
    import flash.geom.Matrix;
    import flash.media.Video;
    import flash.text.TextField;
    import flash.text.TextFormat;
    import flash.utils.ByteArray;
    
    
    /**
     * Simple Minko + IN2AR demo
     * You can switch base class to compile for FLASH/AIR(ANE)
     * @author Eugene Zatepyakin
     */
    
    [SWF(width='640', height='480', frameRate='30',backgroundColor='0xFFFFFF')]
    public final class MinkoDemo extends /* IN2ARNativeBase */  IN2ARBase 
    {
        // tracking data file
        [Embed(source="../assets/def_data.ass", mimeType="application/octet-stream")]
        public static const DefinitionaData:Class;
        
        // asfeat variables
        public var intrinsic:IntrinsicParameters;
        public var maxPoints:int = 300; // max points to allow to detect
        public var maxReferences:int = 1; // max objects will be used
        public var maxTrackIterations:int = 5; // track iterations
        
        // different visual objects
        private var video:Video;
        private var cameraBuffer:BitmapData;
        private var workBuffer:BitmapData;
        private var cameraMatrix:Matrix;
        public static var text:TextField;
        
        // 3d stuff
        private var scene:Scene;
        private var camera:Camera;
        private var view:Viewport;
        private var cameraController:MinkoCameraController;
        private var cameraMesh:MinkoCaptureMesh;
        private var model:IN2ARLogoModel;
        private var container:MinkoContainer;
        
        // camera and viewport options
        public var streamW:int = 640;
        public var streamH:int = 480;
        public var streamFPS:int = 30;
        public var downScaleRatio:Number = 1;
        public var workW:int = streamW * downScaleRatio;
        public var workH:int = streamH * downScaleRatio;
        public var viewWidth:int = 640;
        public var viewHeight:int = 480;
        public var mirror:Boolean = true; // mirror camera output
        
        public function MinkoDemo() 
        {            
            addEventListener(Event.INIT, initIN2AR);
            
            super();
        }
        
        private function initIN2AR(e:Event = null):void
        {   
            removeEventListener(Event.INIT, initIN2AR);
            
            // init our engine
            in2arLib.init( workW, workH, maxPoints, maxReferences, 100, stage );
            
            // indexing reference data will result in huge
            // speed up during matching (see docs for more info)
            // !!! u always need to setup indexing even if u dont plan to use it !!!
            in2arLib.setupIndexing(12, 10, true);
            
            // but u can switch it off if u want
            in2arLib.setUseLSHDictionary(true);
            
            in2arLib.addReferenceObject( ByteArray( new DefinitionaData ) );
            
            // ATTENTION 
            // limit the amount of references to be detected per frame
            // if u have only one reference u can skip this option
            in2arLib.setMaxReferencesPerFrame(1);
            
            intrinsic = in2arLib.getIntrinsicParams();
            
            initCamera();
            initMinko();
            initText();
            initListeners();
        }
        
        private function initMinko():void
        {           
            view = new Viewport(2, viewWidth, viewHeight);
            scene = new Scene();
            camera = new Camera();
            
            cameraMesh = new MinkoCaptureMesh(viewWidth, viewHeight, streamW, streamH);
            cameraMesh.mirror = mirror;
            if(cameraBuffer) cameraMesh.setupForBitmapData(cameraBuffer);
            
            cameraController = new MinkoCameraController();
            cameraController.setupProjectionMatrix(intrinsic, viewWidth, viewHeight, workW, workH);
            camera.removeAllControllers();
            camera.addController(cameraController);
            
            scene.addChild(camera);            
            scene.addChild(cameraMesh);
            
            model = new IN2ARLogoModel();
            container = new MinkoContainer();
            
            container.addChild(model);            
            scene.addChild(container);
            
            container.toggleVisibility(container, false);
            
            addChild(view);
        }
        
        private function initText():void
        {
            // DEBUG TEXT FIELD
            text = new TextField();
            text.defaultTextFormat = new TextFormat("Verdana", 11, 0xFFFFFF);
            text.background = true;
            text.backgroundColor = 0x000000;
            text.textColor = 0xFFFFFF;
            text.width = 640;
            text.height = 18;
            text.selectable = false;
            text.mouseEnabled = false;
            text.y = stage.stageHeight - text.height;
            addChild(text);
        }
        
        private function initListeners():void
        {
            in2arLib.addListener(IN2ARDetectionEvent.DETECTED, onModelDetected);
            in2arLib.addListener(IN2ARDetectionEvent.FAILED, onDetectionFailed);
            addEventListener(Event.ENTER_FRAME, onEnterFrame);
        }
        
        private function onEnterFrame(e:Event = null):void
        {            
            if(cameraBuffer){
                cameraBuffer.draw(video);
                if(downScaleRatio != 1){
                    workBuffer.draw(cameraBuffer, cameraMatrix);
                    // run in2ar
                    in2arLib.detect(workBuffer);
                } else {
                    // run in2ar
                    in2arLib.detect(cameraBuffer);
                }
                
                cameraMesh.invalidate();
            }
            scene.render(view);
        }
        
        private function onModelDetected(e:IN2ARDetectionEvent):void
        {
            var refList:Vector.<IN2ARReference> = e.detectedReferences;
            var ref:IN2ARReference;
            var n:int = e.detectedReferencesCount;
            var state:String;
            
            for(var i:int = 0; i < n; ++i) {
                ref = refList[i];
                state = ref.detectType;
                
                container.in2arTransform(ref, 0.8, mirror);
                
                text.text = state;
                text.appendText( ' @ ' + ref.id );
                
                if(state == '_detect')
                    text.appendText( ' :: matched: ' + ref.matchedPointsCount );
            }
        }
        
        private function onDetectionFailed(e:IN2ARDetectionEvent):void 
        {
            text.text = "nothing found";
            container.lost();
        }
        
        protected function initCamera():void
        {
            var camera:flash.media.Camera = flash.media.Camera.getCamera();
            camera.setMode(streamW, streamH, streamFPS, false);
            
            video = new Video(camera.width, camera.height);
            video.attachCamera(camera);
            
            cameraBuffer = new BitmapData(streamW, streamH, true, 0x0);
            workBuffer = new BitmapData(workW, workH, true, 0x0);
            cameraMatrix = new Matrix(downScaleRatio, 0, 0, downScaleRatio);
            
            if (cameraMesh) {
                cameraMesh.setupForBitmapData(cameraBuffer);
            }
        }
        
    }

}