/** @module forms/enfugue/image-editor */
import { isEmpty } from "../../base/helpers.mjs";
import { FormView } from "../../forms/base.mjs";
import {
    PromptInputView,
    FloatInputView,
    NumberInputView,
    CheckboxInputView,
    ImageColorSpaceInputView,
    ControlNetInputView,
    ImageFitInputView,
    ImageAnchorInputView,
    FilterSelectInputView,
    SliderPreciseInputView
} from "../../forms/input.mjs";

class ImageEditorNodeOptionsFormView extends FormView {
    /**
     * @var object The fieldsets of the options form for image mode.
     */
    static fieldSets = {
        "Prompts": {
            "prompt": {
                "label": "Prompt",
                "class": PromptInputView,
                "config": {
                    "tooltip": "This prompt will control what is in this frame. When left blank, the global prompt will be used."
                }
            },
            "negativePrompt": {
                "label": "Negative Prompt",
                "class": PromptInputView,
                "config": {
                    "tooltip": "This prompt will control what is in not this frame. When left blank, the global negative prompt will be used."
                }
            },
        },
        "Tweaks": {
            "guidanceScale": {
                "label": "Guidance Scale",
                "class": FloatInputView,
                "config": {
                    "min": 0.0,
                    "max": 100.0,
                    "step": 0.1,
                    "value": null,
                    "tooltip": "How closely to follow the text prompt; high values result in high-contrast images closely adhering to your text, low values result in low-contrast images with more randomness."
                }
            },
            "inferenceSteps": {
                "label": "Inference Steps",
                "class": NumberInputView,
                "config": {
                    "min": 5,
                    "max": 250,
                    "step": 1,
                    "value": null,
                    "tooltip": "How many steps to take during primary inference, larger values take longer to process."
                }
            }
        },
        "Other": {
            "scaleToModelSize": {
                "label": "Scale to Model Size",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When this node has any dimension smaller than the size of the configured model, scale it up so it's smallest dimension is the same size as the model, then scale it down after diffusion.<br />This generally improves image quality in slightly rectangular shapes or square shapes smaller than the engine size, but can also result in ghosting and increased processing time.<br />This will have no effect if your node is larger than the model size in all dimensions.<br />If unchecked and your node is smaller than the model size, TensorRT will be disabled for this node."
                },
            },
            "removeBackground": {
                "label": "Remove Background",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "After diffusion, run the resulting image though an AI background removal algorithm. This can improve image consistency when using multiple nodes."
                }
            }
        },
    };
    
    /**
     * @var bool Never show submit button
     */
    static autoSubmit = true;

    /**
     * @var string An additional classname for this form
     */
    static className = "options-form-view";

    /**
     * @var array Collapsed field sets
     */
    static collapseFieldSets = ["Tweaks"];
};

/**
 * This form combines all image options.
 */
class ImageEditorImageNodeOptionsFormView extends FormView {
    /**
     * @var object The fieldsets of the options form for image mode.
     */
    static fieldSets = {
        "Base": {
            "fit": {
                "label": "Image Fit",
                "class": ImageFitInputView
            },
            "anchor": {
                "label": "Image Anchor",
                "class": ImageAnchorInputView
            },
            "inpaint": {
                "label": "Use for Inpainting",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When checked, you will be able to paint where on the image you wish for the AI to fill in details. Any gaps in the frame or transparency in the image will also be filled."
                }
            },
            "infer": {
                "label": "Use for Inference",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When checked, use this image as input for primary diffusion. Inpainting will be performed first, filling any painted sections as well as gaps in the frame and transparency in the image."
                }
            },
            "control": {
                "label": "Use for Control",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When checked, use this image as input for ControlNet. Inpainting will be performed first, filling any painted sections as well as gaps in the frame and transparency in the image.<br />Unless otherwise specified, your image will be processed using the appropriate algorithm for the chosen ControlNet."
                }
            },
            "imagePrompt": {
                "label": "Use for Prompt",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When checked, use this image for Image Prompting. This uses a technique whereby your image is analzyed for descriptors automatically and the 'image prompt' is merged with your real prompt. This can help produce variations of an image without adhering too closely to the original image, and without you having to describe the image yourself."
                }
            }
        },
        "Other": {
            "scaleToModelSize": {
                "label": "Scale to Model Size",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When this has any dimension smaller than the size of the configured model, scale it up so it's smallest dimension is the same size as the model, then scale it down after diffusion.<br />This generally improves image quality in rectangular shapes, but can also result in ghosting and increased processing time.<br />This will have no effect if your node is larger than the model size in all dimensions.<br />If unchecked and your node is smaller than the model size, TensorRT will be disabled for this node."
                },
            },
            "removeBackground": {
                "label": "Remove Background",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "Before processing, run this image through an AI background removal process. If you are additionally inpainting, inferencing or using this image for ControlNet, that background will then be filled in within this frame. If you are not, that background will be filled when the overall canvas image is finally painted in."
                }
            }
        },
        "Image Prompt": {
            "imagePromptScale": {
                "label": "Image Prompt Scale",
                "class": FloatInputView,
                "config": {
                    "tooltip": "How much strength to give to the image. A higher strength will reduce the effect of your prompt, and a lower strength will increase the effect of your prompt but reduce the effect of the image.",
                    "min": 0,
                    "step": 0.01,
                    "value": 0.5
                }
            },
            "imagePromptPlus": {
                "label": "Use Fine-Grained Model",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "Use this to enable fine-grained feature inspection on the source image. This can improve details in the resulting image, but can also make the overall image less similar.<br /><br />Note that when using multiple source images for image prompting, enabling fine-grained feature inspection on any image enables it for all images."
                }
            },
            "imagePromptFace": {
                "label": "Use Face-Specific Model",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "Use this to focus strongly on a face in the input image. This can work very well to copy a face from one image to another in a natural way, instead of needing a separate face-fixing step.<br /><br />Note that at present moment, this feature is only available for Stable Diffusion 1.5 models. This checkbox does nothing for SDXL models."
                }
            }
        },
        "Prompts": {
            "prompt": {
                "label": "Prompt",
                "class": PromptInputView,
                "config": {
                    "tooltip": "This prompt will control what is in this frame. When left blank, the global prompt will be used."
                }
            },
            "negativePrompt": {
                "label": "Negative Prompt",
                "class": PromptInputView,
                "config": {
                    "tooltip": "This prompt will control what is in not this frame. When left blank, the global negative prompt will be used."
                }
            },
        },
        "Tweaks": {
            "guidanceScale": {
                "label": "Guidance Scale",
                "class": FloatInputView,
                "config": {
                    "min": 0.0,
                    "max": 100.0,
                    "step": 0.1,
                    "value": null,
                    "tooltip": "How closely to follow the text prompt; high values result in high-contrast images closely adhering to your text, low values result in low-contrast images with more randomness."
                }
            },
            "inferenceSteps": {
                "label": "Inference Steps",
                "class": NumberInputView,
                "config": {
                    "min": 5,
                    "max": 250,
                    "step": 1,
                    "value": null,
                    "tooltip": "How many steps to take during primary inference, larger values take longer to process."
                }
            }
        },
        "Inference": {
            "strength": {
                "label": "Denoising Strength",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0.0,
                    "max": 1.0,
                    "step": 0.01,
                    "value": 0.8,
                    "tooltip": "How much of the input image to replace with new information. A value of 1.0 represents total input image destruction, and 0.0 represents no image modifications being made."
                }
            }
        },
        "Inpainting": {
            "cropInpaint": {
                "label": "Use Cropped Inpainting",
                "class": CheckboxInputView,
                "config": {
                    "tooltip": "When checked, the image will be cropped to the area you've shaded prior to executing. This will reduce processing time on large images, but can result in losing the composition of the image.",
                    "value": true
                }
            },
            "inpaintFeather": {
                "label": "Cropped Inpaint Feather",
                "class": NumberInputView,
                "config": {
                    "min": 16,
                    "max": 256,
                    "step": 8,
                    "value": 32,
                    "tooltip": "When using cropped inpainting, this is the number of pixels to feather along the edge of the crop in order to help blend in with the rest of the image."
                }
            }
        },
        "Control": {
            "controlnet": {
                "label": "ControlNet",
                "class": ControlNetInputView
            },
            "conditioningScale": {
                "label": "Conditioning Scale",
                "class": FloatInputView,
                "config": {
                    "min": 0.0,
                    "step": 0.01,
                    "value": 1.0,
                    "tooltip": "How closely to follow ControlNet's influence. Typical values vary, usually values between 0.5 and 1.0 produce good conditioning with balanced randomness, but other values may produce something closer to the desired result."
                }
            },
            "conditioningStart": {
                "label": "Conditioning Start",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0.0,
                    "max": 1.0,
                    "step": 0.01,
                    "value": 0.0,
                    "tooltip": "When to begin using this ControlNet for influence. Defaults to the beginning of generation."
                }
            },
            "conditioningEnd": {
                "label": "Conditioning End",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0.0,
                    "max": 1.0,
                    "step": 0.01,
                    "value": 1.0,
                    "tooltip": "When to stop using this ControlNet for influence. Defaults to the end of generation."
                }
            },
            "processControlImage": {
                "label": "Process Image for ControlNet",
                "class": CheckboxInputView,
                "config": {
                    "value": true,
                    "tooltip": "When checked, the image will be processed through the appropriate edge detection algorithm for the ControlNet. Only uncheck this if your image has already been processed through edge detection."
                }
            },
            "invertControlImage": {
                "label": "Invert Image for ControlNet",
                "class": CheckboxInputView,
                "config": {
                    "value": false,
                    "tooltip": "Invert the colors of the control image prior to using it."
                }
            }
        }
    };

    /**
     * @var object The conditions for display of some inputs.
     */
    static fieldSetConditions = {
        "Prompts": (values) => values.infer || values.inpaint || values.control,
        "Tweaks": (values) => values.infer || values.inpaint || values.control,
        "Inpainting": (values) => values.inpaint,
        "Inference": (values) => values.infer,
        "Control": (values) => values.control,
        "Image Prompt": (values) => values.imagePrompt
    };

    /**
     * @var bool Never show submit button
     */
    static autoSubmit = true;

    /**
     * @var string An additional classname for this form
     */
    static className = "image-options-form-view";

    /**
     * @var array Field sets to collapse
     */
    static collapseFieldSets = ["Tweaks"];

    /**
     * On input change, enable/disable flags
     */
    async inputChanged(fieldName, inputView) {
        if (fieldName === "inpaint") {
            let inference = await this.getInputView("infer");
            if (inputView.getValue()) {
                inference.setValue(true, false);
                inference.disable();
                this.values.infer = true;
                this.evaluateConditions();
            } else {
                inference.enable();
            }
        }
        if (fieldName === "processControlImage") {
            if (inputView.getValue()) {
                this.removeClass("no-process");
            } else {
                this.addClass("no-process");
            }
        }
        if (fieldName === "imagePromptPlus") {
            if (inputView.getValue()) {
                this.addClass("prompt-plus");
            } else {
                this.removeClass("prompt-plus");
            }
        }
        return super.inputChanged.call(this, fieldName, inputView);
    }

    /**
     * On set values, check and set classes.
     */
    async setValues() {
        await super.setValues.apply(this, Array.from(arguments));
        if (this.values.control && !this.values.processControlImage) {
            this.addClass("no-process");
        } else {
            this.removeClass("no-process");
        }
        if (this.values.imagePromptPlus) {
            this.addClass("prompt-plus");
        } else {
            this.removeClass("prompt-plus");
        }
        let inference = await this.getInputView("infer");
        if (this.values.inpaint) {
            this.values.infer = true;
            inference.setValue(true, false);
            inference.disable();
        } else {
            inference.enable();
        }
    }
};

/**
 * Creates a common form view base for filter forms
 */
class ImageFilterFormView extends FormView {
    /**
     * @var bool autosubmit
     */
    static autoSubmit = true;

    /**
     * @var bool Disable disabling
     */
    static disableOnSubmit = false;

    /**
     * Fieldsets include the main filter, then inputs for filter types
     */
    static fieldSets = {
        "Filter": {
            "filter": {
                "class": FilterSelectInputView,
            }
        },
        "Size": {
            "size": {
                "class": SliderPreciseInputView,
                "config": {
                    "min": 4,
                    "max": 64,
                    "step": 1,
                    "value": 4
                }
            }
        },
        "Radius": {
            "radius": {
                "class": SliderPreciseInputView,
                "config": {
                    "min": 1,
                    "max": 64,
                    "step": 1,
                    "value": 1
                }
            }
        },
        "Weight": {
            "weight": {
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0,
                    "max": 100,
                    "step": 1,
                    "value": 0
                }
            }
        }
    };

    /**
     * @var object Default values
     */
    static defaultValues = {
        "filter": null,
        "size": 16,
        "radius": 2,
        "weight": 0
    };

    /**
     * @var object Callable conditions for fieldset display
     */
    static fieldSetConditions = {
        "Size": (values) => ["pixelize"].indexOf(values.filter) !== -1,
        "Radius": (values) => ["gaussian", "box", "sharpen"].indexOf(values.filter) !== -1,
        "Weight": (values) => ["sharpen"].indexOf(values.filter) !== -1
    };
};

/**
 * Creates a form view for controlling the ImageAdjustmentFilter
 */
class ImageAdjustmentFormView extends ImageFilterFormView {
    /**
     * @var object Various options available
     */
    static fieldSets = {
        "Color Channel Adjustments": {
            "red": {
                "label": "Red Amount",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            },
            "green": {
                "label": "Green Amount",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            },
            "blue": {
                "label": "Blue Amount",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            }
        },
        "Brightness and Contrast": {
            "brightness": {
                "label": "Brightness Adjustment",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            },
            "contrast": {
                "label": "Contrast Adjustment",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            }
        },
        "Hue, Saturation and Lightness": {
            "hue": {
                "label": "Hue Shift",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            },
            "saturation": {
                "label": "Saturation Adjustment",
                "class": SliderPreciseInputView,
                "config": {
                    "min": -100,
                    "max": 100,
                    "value": 0
                }
            },
            "lightness": {
                "label": "Lightness Enhancement",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0,
                    "max": 100,
                    "value": 0
                }
            }
        },
        "Noise": {
            "hueNoise": {
                "label": "Hue Noise",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0,
                    "max": 100,
                    "value": 0
                }
            },
            "saturationNoise": {
                "label": "Saturation Noise",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0,
                    "max": 100,
                    "value": 0
                }
            },
            "lightnessNoise": {
                "label": "Lightness Noise",
                "class": SliderPreciseInputView,
                "config": {
                    "min": 0,
                    "max": 100,
                    "value": 0
                }
            }
        }
    };

    /**
     * @var object Default values
     */
    static defaultValues = {
        "red": 0,
        "green": 0,
        "blue": 0,
        "brightness": 0,
        "contrast": 0,
        "hue": 0,
        "saturation": 0,
        "lightness": 0,
        "hueNoise": 0,
        "saturationNoise": 0,
        "lightnessNoise": 0
    };
};

export {
    ImageEditorNodeOptionsFormView,
    ImageEditorImageNodeOptionsFormView,
    ImageFilterFormView,
    ImageAdjustmentFormView
};
