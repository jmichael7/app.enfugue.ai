"""
Runs an end-to-end test of an active installation.
"""
import os
import re

from pibble.util.log import DebugUnifiedLoggingContext

from enfugue.diffusion.constants import DEFAULT_SDXL_MODEL, DEFAULT_SDXL_REFINER
from enfugue.client import EnfugueClient
from enfugue.util import logger, fit_image, image_from_uri
from PIL import Image, ImageDraw, ImageFont
from collections import OrderedDict
from typing import Any, List

GRID_SIZE = 256
GRID_COLS = 4
CAPTION_HEIGHT = 50
CHECKPOINT = "epicphotogasm_x.safetensors"
CHECKPOINT_URL = "https://civitai.com/api/download/models/172306?type=Model&format=SafeTensor&size=pruned&fp=fp16"
INPAINT_IMAGE = "https://huggingface.co/datasets/diffusers/test-arrays/resolve/main/stable_diffusion_inpaint/boy.png"
INPAINT_MASK = "https://huggingface.co/datasets/diffusers/test-arrays/resolve/main/stable_diffusion_inpaint/boy_mask.png"

def split_text(text: str, maxlen: int = 40) -> str:
    """
    Splits text into lines based on max length.
    """
    lines = 1 + len(text) // maxlen
    return "\n".join([
        text[(i*maxlen):((i+1)*maxlen)]
        for i in range(lines)
    ])

def main() -> None:
    font = ImageFont.load_default()
    with DebugUnifiedLoggingContext():
        save_dir = os.path.join(os.path.dirname(os.path.abspath(__file__)), "test-results", "e2e")
        if not os.path.exists(save_dir):
            os.makedirs(save_dir)

        client = EnfugueClient()
        # Override client variables with ENFUGUE_CLIENT_HOST, ENFUGUE_CLIENT_PORT, etc. env vars
        client.configure(
            client = {
                "host": "app.enfugue.ai",
                "port": 45554,
                "secure": True,
            },
            enfugue = {
                "username": "enfugue",
                "password": "enfugue"
            }
        )

        all_results = OrderedDict()

        def save_results(name: str, results: List[Image.Image]) -> List[Image.Image]:
            nonlocal all_results
            for i, result in enumerate(results):
                result_path = os.path.join(save_dir, f"{name}-{i}.png")
                result.save(result_path)
                logger.info(f"Saved result for \"{name}\" sample {i+1} to {result_path}")
            all_results[name] = results
            return results

        def invoke(name: str, **kwargs: Any) -> List[Image.Image]:
            existing_results = [
                filename for filename 
                in os.listdir(save_dir) 
                if re.match(f"^{name}\-\d+\..*$", filename)
            ]
            if existing_results:
                results = [
                    Image.open(os.path.join(save_dir, result))
                    for result in existing_results
                ]
                logger.info(f"Found existing results {existing_results}, skipping test {name}")
                nonlocal all_results
                all_results[name] = results
                return results
            results = []
            if "seed" not in kwargs:
                # Two seeds for controlled/non-controlled:
                # Controlnet doesn't change enough if it uses the same
                # seed as the prompt the image was generated with
                kwargs["seed"] = 12345 if "control_images" in kwargs else 54321
            if "model" not in kwargs:
                kwargs["model"] = CHECKPOINT
            kwargs["intermediates"] = False
            kwargs["num_inference_steps"] = 25
            logger.info(f"Testing {name}\n{kwargs}")
            result = client.invoke(**kwargs)
            try:
                images = result.results()
            except Exception as ex:
                logger.error(f"Error in invocation {name}: {type(ex).__name__}({ex})")
                image = Image.new("RGB", (GRID_SIZE, GRID_SIZE), (255,255,255))
                draw = ImageDraw.Draw(image)
                draw.text(
                    (5, 5),
                    split_text(str(ex)),
                    fill=(0,0,0),
                    font=font
                )
                images = [image] * kwargs.get("samples", 1)
                name = f"{name} ({type(ex).__name__})"
            result.delete()
            return save_results(name, images)

        gpu_name = "Unknown GPU"
        status = client.status()
        if "gpu" in status and isinstance(status["gpu"], dict):
            gpu = status["gpu"]
            gpu_name = gpu.get("name", gpu_name)
        
        logger.info(f"Starting e2e test on {gpu_name}")
        checkpoints = client.checkpoints()
        if CHECKPOINT not in [checkpoint["name"] for checkpoint in checkpoints]:
            logger.info(f"Downloading checkpoint {CHECKPOINT}")
            client.download("checkpoint", CHECKPOINT_URL, filename=CHECKPOINT)
        
        # Base txt2img
        prompt = "A man and woman standing outside a house, happy couple purchasing their first home, wearing casual clothing"
        base = invoke("txt2img", prompt=prompt)[0]
        
        # Base img2img
        invoke(
            "img2img",
            prompt=prompt,
            image=base,
            strength=0.8
        )
        
        # Base inpaint + fit
        inpaint_image = image_from_uri(INPAINT_IMAGE)
        inpaint_mask = image_from_uri(INPAINT_MASK)
        invoke(
            "inpaint", 
            prompt="a handsome man with ray-ban sunglasses",
            image=inpaint_image,
            mask=inpaint_mask,
            width=512,
            height=512,
            fit="cover"
        )

        invoke(
            "inpaint-4ch",
            inpainter=CHECKPOINT,
            prompt="a handsome man with ray-ban sunglasses",
            image=inpaint_image,
            mask=inpaint_mask,
            width=512,
            height=512,
            fit="cover"
        )

        # Automatic background removal with no inference
        invoke(
            "background", 
            image=inpaint_image,
            remove_background=True,
        )
        
        # Automatic background removal with outpaint
        invoke(
            "background-fill",
            prompt="a handsome man outside on a sunny day, green forest in the distance",
            image=inpaint_image,
            remove_background=True,
            fill_background=True
        )

        # IP Adapter
        invoke(
            "ip-adapter",
            ip_adapter_images=[{
                "image": inpaint_image,
                "scale": 0.3
            }]
        )
        invoke(
            "ip-adapter-plus",
            ip_adapter_plus=True,
            ip_adapter_images=[{
                "image": inpaint_image,
                "scale": 0.3
            }]
        )
        invoke(
            "ip-adapter-plus-face",
            ip_adapter_plus=True,
            ip_adapter_face=True,
            ip_adapter_images=[{
                "image": inpaint_image, 
                "scale": 0.3
            }]
        )
        
        # Sizing, fitting and outpaint
        invoke(
            "outpaint", 
            prompt="a handsome man walking outside on a boardwalk, distant house, foggy weather, dark clouds overhead",
            negative_prompt="frame, framing, comic book paneling, multiple images, awning, roof, shelter, trellice",
            nodes=[
                {
                    "image": inpaint_image,
                    "x": 128,
                    "y": 256,
                    "w": 256,
                    "h": 256,
                    "fit": "cover"
                }
            ],
            strength=1.0
        )

        # Regions + multi-diffusion
        invoke(
            "regions", 
            prompt="Roses in a bouquet",
            chunking_size=128,
            nodes=[
                {
                    "x": 0,
                    "y": 0,
                    "w": 256,
                    "h": 512,
                    "prompt": "A single red rose, white background",
                    "negative_prompt": "bouquet",
                    "remove_background": True
                },
                {
                    "x": 256,
                    "y": 0,
                    "w": 256,
                    "h": 512,
                    "prompt": "A single white rose, black background",
                    "negative_prompt": "bouquet",
                    "remove_background": True
                }
            ]
        )
        
        # Controlnets
        for controlnet in ["canny", "hed", "pidi", "scribble", "depth", "normal", "mlsd", "line", "anime", "pose"]:
            invoke(
                f"txt2img-controlnet-{controlnet}",
                prompt=prompt,
                control_images=[{
                    "controlnet": controlnet,
                    "image": base,
                }]
            )
            
            invoke(
                f"img2img-controlnet-{controlnet}",
                prompt=prompt,
                image=base,
                strength=0.8,
                control_images=[{
                    "controlnet": controlnet,
                    "image": base,
                }]
            )
            
            invoke(
                f"img2img-ip-controlnet-{controlnet}",
                prompt=prompt,
                image=base,
                strength=0.8,
                ip_adapter_images=[{
                    "image": base,
                    "scale": 0.5
                }],
                control_images=[{
                    "controlnet": controlnet,
                    "image": base,
                }]
            )
        
        # Schedulers
        for scheduler in ["ddim", "ddpm", "deis", "dpmsm", "dpmss", "dpmsmk", "dpmsmka", "heun", "dpmd", "adpmd", "dpmsde", "unipc", "lmsd", "pndm", "eds", "eads"]:
            invoke(
                f"txt2img-scheduler-{scheduler}",
                prompt=prompt,
                scheduler=scheduler
            )

            invoke(
                f"txt2img-multi-scheduler-{scheduler}",
                prompt=prompt,
                scheduler=scheduler,
                height=768,
                width=786,
                chunking_size=256,
            )

        # Upscalers
        invoke(
            f"upscale-standalone-esrgan",
            upscale_steps=[{
                "amount": 2,
                "method": "esrgan"
            }],
            image=base
        )
        invoke(
            f"upscale-standalone-gfpgan",
            upscale_steps=[{
                "amount": 2,
                "method": "gfpgan"
            }],
            image=base
        )
        invoke(
            f"upscale-iterative-diffusion",
            prompt="A green tree frog",
            upscale_steps=[
                {
                    "amount": 2,
                    "method": "esrgan",
                    "strength": 0.15,
                    "controlnets": "tile",
                    "chunking_size": 128,
                    "guidance_scale": 8
                },
                {
                    "amount": 2,
                    "method": "esrgan",
                    "strength": 0.1,
                    "controlnets": "tile",
                    "chunking_size": 256,
                    "guidance_scale": 8
                }
            ],
        )

        # SDXL
        if os.getenv("TEST_SDXL", "0").lower()[0] in ["1", "y", "t"]:
            invoke(
                "sdxl",
                model=DEFAULT_SDXL_MODEL,
                prompt="A bride and groom on their wedding day",
                guidance_scale=6
            )

            invoke(
                "sdxl-inpaint",
                prompt="a handsome man with ray-ban sunglasses",
                model=DEFAULT_SDXL_MODEL,
                image=fit_image(inpaint_image, width=1024, height=1024, fit="stretch"),
                mask=fit_image(inpaint_mask, width=1024, height=1024, fit="stretch"),
                width=1024,
                height=1024,
            )

            invoke(
                "sdxl-inpaint-4ch",
                prompt="a handsome man with ray-ban sunglasses",
                inpainter=DEFAULT_SDXL_MODEL,
                image=fit_image(inpaint_image, width=1024, height=1024, fit="stretch"),
                mask=fit_image(inpaint_mask, width=1024, height=1024, fit="stretch"),
                width=1024,
                height=1024,
            )

            control = invoke(
                "sdxl-refined",
                model=DEFAULT_SDXL_MODEL,
                refiner=DEFAULT_SDXL_REFINER,
                prompt="A bride and groom on their wedding day",
                refiner_start=0.85,
                guidance_scale=6
            )[0]
            
            # SDXL ControlNet
            for controlnet in ["canny", "depth", ]:
                invoke(
                    f"sdxl-{controlnet}-txt2img",
                    model=DEFAULT_SDXL_MODEL,
                    control_images=[{
                        "controlnet": controlnet,
                        "image": control,
                        "scale": 0.5
                    }],
                    prompt="A bride and groom on their wedding day",
                    guidance_scale=6
                )[0]
                
                invoke(
                    f"sdxl-{controlnet}-txt2img-refined",
                    model=DEFAULT_SDXL_MODEL,
                    refiner=DEFAULT_SDXL_REFINER,
                    control_images=[{
                        "controlnet": controlnet,
                        "image": control,
                        "scale": 0.5
                    }],
                    prompt="A bride and groom on their wedding day",
                    refiner_start=0.85,
                    guidance_scale=6
                )[0]
                
                invoke(
                    f"sdxl-{controlnet}-img2img",
                    model=DEFAULT_SDXL_MODEL,
                    image=control,
                    strength=0.8,
                    control_images=[
                        {
                            "controlnet": controlnet,
                            "image": control,
                            "scale": 0.5
                        }
                    ],
                    prompt="A bride and groom on their wedding day",
                    guidance_scale=6
                )[0]
                
                invoke(
                    f"sdxl-{controlnet}-img2img-refined",
                    model=DEFAULT_SDXL_MODEL,
                    refiner=DEFAULT_SDXL_REFINER,
                    control_images=[
                        {
                            "controlnet": controlnet,
                            "image": control,
                            "scale": 0.5
                        }
                    ],
                    image=control,
                    strength=0.8,
                    refiner_start=0.85,
                    prompt="A bride and groom on their wedding day",
                    guidance_scale=6
                )[0]
               
                invoke(
                    f"sdxl-{controlnet}-img2img-ip-refined",
                    model=DEFAULT_SDXL_MODEL,
                    refiner=DEFAULT_SDXL_REFINER,
                    control_images=[
                        {
                            "controlnet": controlnet,
                            "image": control,
                            "scale": 0.5
                        }
                    ],
                    image=control,
                    strength=0.8,
                    ip_adapter_images=[{
                        "image": control,
                        "scale": 0.5
                    }],
                    prompt="A bride and groom on their wedding day",
                    refiner_start=0.85,
                    guidance_scale=6
                )[0]

                invoke(
                    f"sdxl-{controlnet}-img2img-ip-plus-refined",
                    model=DEFAULT_SDXL_MODEL,
                    refiner=DEFAULT_SDXL_REFINER,
                    control_images=[
                        {
                            "controlnet": controlnet,
                            "image": control,
                            "scale": 0.5
                        }
                    ],
                    image=control,
                    strength=0.8,
                    ip_adapter_images=[{
                        "image": control,
                        "scale": 0.5
                    }],
                    ip_adapter_plus=True,
                    prompt="A bride and groom on their wedding day",
                    refiner_start=0.85,
                    guidance_scale=6
                )[0]

        # Make grid
        total_results = sum([len(arr) for arr in all_results.values()])
        rows = (total_results // GRID_COLS) + 1
        cols = total_results % GRID_COLS if total_results < GRID_COLS else GRID_COLS
        width = GRID_SIZE * cols
        height = (GRID_SIZE * rows) + (CAPTION_HEIGHT * rows)
        grid = Image.new("RGB", (width, height), (255, 255, 255))
        draw = ImageDraw.Draw(grid)
        row, col = 0, 0

        for name in all_results:
            for i, image in enumerate(all_results[name]):
                width, height = image.size
                image = fit_image(image, GRID_SIZE, GRID_SIZE, "contain", "center-center")
                grid.paste(image, (col * GRID_SIZE, row * (GRID_SIZE + CAPTION_HEIGHT)))
                draw.text(
                    (col * GRID_SIZE + 5, row * (GRID_SIZE + CAPTION_HEIGHT) + GRID_SIZE + 2),
                    split_text(f"\"{name}\", sample {i+1}, {width}×{height}"),
                    fill=(0,0,0),
                    font=font
                )
                col += 1
                if col >= GRID_COLS:
                    row += 1
                    col = 0
        
        grid_path = os.path.join(save_dir, "grid.png")
        grid.save(grid_path)
        logger.info(f"Saved grid result at {grid_path}")


if __name__ == "__main__":
    main()
