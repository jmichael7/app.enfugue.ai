/** @module controller/sidebar/03-tweaks */
import { isEmpty } from "../../base/helpers.mjs";
import { Controller } from "../base.mjs";
import { TweaksFormView } from "../../forms/enfugue/tweaks.mjs";

/**
 * Extend the menu controll to bind init
 */
class TweaksController extends Controller {
    /**
     * Return data from the tweaks form
     */
    getState(includeImages = true) {
        return { "tweaks": this.tweaksForm.values };
    }

    /**
     * Sets state in the form
     */
    setState(newState) {
        if (!isEmpty(newState.tweaks)) {
            this.tweaksForm.setValues(newState.tweaks).then(() => this.tweaksForm.submit());
        }
    }

    /**
     * Gets default state
     */
    getDefaultState() {
        return {
            "tweaks": {
                "guidanceScale": this.config.model.invocation.guidanceScale,
                "inferenceSteps": this.config.model.invocation.inferenceSteps,
                "scheduler": null,
                "clipSkip": 0,
                "enableFreeU": false,
                "freeUBackbone1": 1.2,
                "freeUBackbone2": 1.4,
                "freeUSkip1": 0.9,
                "freeUSkip2": 0.2,
                "noiseOffset": 0.0,
                "noiseMethod": "perlin",
                "noiseBlendMethod": "inject"
            }
        }
    }

    /**
     * On initialization, append the Tweaks form
     */
    async initialize() {
        // Builds form
        this.tweaksForm = new TweaksFormView(this.config);
        this.tweaksForm.onSubmit(async (values) => {
            this.engine.guidanceScale = values.guidanceScale;
            this.engine.inferenceSteps = values.inferenceSteps;
            this.engine.scheduler = values.scheduler;
            this.engine.clipSkip = values.clipSkip;
            this.engine.noiseOffset = values.noiseOffset;
            this.engine.noiseMethod = values.noiseMethod;
            this.engine.noiseBlendMethod = values.noiseBlendMethod;
            if (values.enableFreeU) {
                this.engine.freeUFactors = [
                    values.freeUBackbone1,
                    values.freeUBackbone2,
                    values.freeUSkip1,
                    values.freeUSkip2
                ];
            } else {
                this.engine.freeUFactors = null;
            }
        });

        // Subscribe to model changes to look for defaults
        this.subscribe("modelPickerChange", (newModel) => {
            if (!isEmpty(newModel)) {
                let defaultConfig = newModel.defaultConfiguration,
                    tweaksConfig = {};
                
                if (!isEmpty(defaultConfig.guidance_scale)) {
                    tweaksConfig.guidanceScale = defaultConfig.guidance_scale;
                }
                if (!isEmpty(defaultConfig.inference_steps)) {
                    tweaksConfig.inferenceSteps = defaultConfig.inference_steps;
                }
                if (!isEmpty(defaultConfig.clip_skip)) {
                    tweaksConfig.clipSkip = defaultConfig.clip_skip;
                }
                if (!isEmpty(defaultConfig.noise_offset)) {
                    tweaksConfig.noiseOffset = defaultConfig.noise_offset;
                }
                if (!isEmpty(defaultConfig.noise_method)) {
                    tweaksConfig.noiseMethod = defaultConfig.noise_method;
                }
                if (!isEmpty(defaultConfig.noise_blend_method)) {
                    tweaksConfig.noiseBlendMethod = defaultConfig.noise_blend_method;
                }
                if (!isEmpty(defaultConfig.freeu_factors)) {
                    tweaksConfig.enableFreeU = true;
                    tweaksConfig.freeUBackbone1 = defaultConfig.freeu_factors[0];
                    tweaksConfig.freeUBackbone2 = defaultConfig.freeu_factors[1];
                    tweaksConfig.freeUSkip1 = defaultConfig.freeu_factors[2];
                    tweaksConfig.freeUSkip2 = defaultConfig.freeu_factors[3];
                } else {
                    tweaksConfig.enableFreeU = false;
                }
                if (!isEmpty(newModel.scheduler)) {
                    tweaksConfig.scheduler = newModel.scheduler[0].name;
                }
                if (!isEmpty(tweaksConfig)) {
                    this.tweaksForm.setValues(tweaksConfig);
                }
            }
        });

        // Add to sidebar
        this.application.sidebar.addChild(this.tweaksForm);
    }
}

export { TweaksController as SidebarController }
