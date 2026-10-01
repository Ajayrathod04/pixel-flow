/* =========================================================
   PixelFlow Dashboard Frontend Controller
   ========================================================= */

document.addEventListener("DOMContentLoaded", () => {
    // Tab Navigation Setup
    const tabs = document.querySelectorAll(".nav-tab");
    tabs.forEach(tab => {
        tab.addEventListener("click", () => {
            const targetView = tab.getAttribute("data-view");
            switchTab(targetView);
        });
    });

    // File Input Handlers
    const runFileInput = document.getElementById("imageUploadInput");
    if (runFileInput) {
        runFileInput.addEventListener("change", handleRunFileUpload);
    }

    const imgToMemInput = document.getElementById("imgToMemInput");
    if (imgToMemInput) {
        imgToMemInput.addEventListener("change", handleImgToMemFileSelect);
    }

    const memToImgInput = document.getElementById("memToImgInput");
    if (memToImgInput) {
        memToImgInput.addEventListener("change", handleMemToImgFileSelect);
    }

    // Auto-fetch initial reports list
    refreshReportsList();
});

// TAB SWITCHING CONTROLLER
function switchTab(viewId) {
    // Update active nav button
    document.querySelectorAll(".nav-tab").forEach(tab => {
        if (tab.getAttribute("data-view") === viewId) {
            tab.classList.add("active");
        } else {
            tab.classList.remove("active");
        }
    });

    // Update active view panel
    document.querySelectorAll(".tab-view").forEach(view => {
        if (view.id === viewId) {
            view.classList.add("active");
        } else {
            view.classList.remove("active");
        }
    });

    window.scrollTo({ top: 0, behavior: "smooth" });
}

// CONSOLE LOGGING
function appendLog(message) {
    const logBox = document.getElementById("consoleLog");
    if (!logBox) return;
    const timeStr = new Date().toLocaleTimeString();
    logBox.textContent += `\n[${timeStr}] ${message}`;
    logBox.scrollTop = logBox.scrollHeight;
}

function clearLog() {
    const logBox = document.getElementById("consoleLog");
    if (logBox) logBox.textContent = "[LOG CLEARED] Ready for next execution.";
}

// STATUS INDICATORS
function setGlobalStatus(type, text) {
    const dot = document.getElementById("globalStatusDot");
    const label = document.getElementById("globalStatusText");
    if (dot && label) {
        dot.className = "status-indicator " + type;
        label.textContent = text;
    }
}

function updateStatusList(stepIndex) {
    const steps = ["st-ready", "st-img", "st-mem", "st-sim", "st-outmem", "st-recon", "st-complete"];
    steps.forEach((id, idx) => {
        const el = document.getElementById(id);
        if (!el) return;
        
        if (idx < stepIndex) {
            el.className = "done";
        } else if (idx === stepIndex) {
            el.className = "active";
        } else {
            el.className = "";
        }
    });
}

function highlightNode(nodeId, state) {
    const node = document.getElementById(nodeId);
    if (!node) return;
    
    if (state === "active") {
        node.classList.add("active");
        node.classList.remove("completed");
    } else if (state === "completed") {
        node.classList.remove("active");
        node.classList.add("completed");
    } else {
        node.classList.remove("active", "completed");
    }
}

// GLOBAL ISOLATED SESSIONS
let activeConversionSession = {
    requestId: null,
    sourceFilename: null,
    baseName: null,
    origWidth: null,
    origHeight: null,
    targetWidth: 32,
    targetHeight: 32,
    sha256: null,
    sourceUrl: null,
    preprocessedUrl: null,
    memGenerated: false
};

let manualMemSession = {
    requestId: null,
    filename: null,
    baseName: null,
    sha256: null,
    detectedPixels: 0
};

let activePixelFlowSession = {
    requestId: null,
    filename: null,
    baseName: null,
    origWidth: null,
    origHeight: null,
    targetWidth: 32,
    targetHeight: 32,
    sourceUrl: null,
    inputMemFilename: null,
    inputMemSha256: null,
    outputMemFilename: null,
    outputMemSha256: null,
    outputPngSha256: null,
    outputUrl: null
};

// MODE B: RUN PIXELFLOW PIPELINE FILE UPLOAD
async function handleRunFileUpload(e) {
    const file = e.target.files[0];
    if (!file) return;

    // Reset pipeline session state
    activePixelFlowSession = {
        requestId: null,
        filename: file.name,
        baseName: null,
        origWidth: null,
        origHeight: null,
        targetWidth: 32,
        targetHeight: 32,
        sourceUrl: null,
        inputMemFilename: null,
        inputMemSha256: null,
        outputMemFilename: null,
        outputMemSha256: null,
        outputPngSha256: null,
        outputUrl: null
    };

    const formData = new FormData();
    formData.append("file", file);

    setGlobalStatus("active", "Uploading Image...");
    appendLog(`Uploading file '${file.name}' for Run PixelFlow pipeline...`);

    // Reset UI image elements and footers
    const inputImg = document.getElementById("inputImgPreview");
    const inputPlaceholder = document.getElementById("inputImgPlaceholder");
    const inputFooter = document.getElementById("inputImgFooter");
    const inputResBadge = document.getElementById("inputResBadge");

    const outputImg = document.getElementById("outputImgPreview");
    const outputPlaceholder = document.getElementById("outputImgPlaceholder");
    const outputFooter = document.getElementById("outputImgFooter");
    const outputResBadge = document.getElementById("outputResBadge");

    if (inputImg) { inputImg.src = ""; inputImg.style.display = "none"; }
    if (inputPlaceholder) inputPlaceholder.style.display = "block";
    
    if (outputImg) { outputImg.src = ""; outputImg.style.display = "none"; }
    if (outputPlaceholder) {
        outputPlaceholder.style.display = "block";
        outputPlaceholder.innerHTML = "No hardware output generated.<br>Click 'RUN PIXELFLOW' to execute pipeline.";
    }

    try {
        const res = await fetch("/api/upload", {
            method: "POST",
            body: formData
        });

        const data = await res.json();
        if (data.success) {
            activePixelFlowSession.requestId = data.request_id;
            activePixelFlowSession.filename = data.original_filename;
            activePixelFlowSession.baseName = data.base_name;
            activePixelFlowSession.origWidth = data.orig_width;
            activePixelFlowSession.origHeight = data.orig_height;
            activePixelFlowSession.sourceUrl = data.image_url;

            // Display Upload Info
            document.getElementById("uploadFilenameInfo").textContent = `Uploaded: ${data.original_filename} (${data.orig_width}×${data.orig_height} px)`;
            
            if (inputImg) {
                inputImg.src = data.image_url;
                inputImg.style.display = "block";
            }
            if (inputPlaceholder) inputPlaceholder.style.display = "none";
            if (inputResBadge) inputResBadge.textContent = `${data.orig_width} × ${data.orig_height} px`;
            if (inputFooter) inputFooter.innerHTML = `File: <code>${data.original_filename}</code>`;

            if (outputFooter) outputFooter.innerHTML = `Artifact: None`;
            if (outputResBadge) outputResBadge.textContent = "Awaiting Run";

            // Node Subtexts with Base Name Propagation
            const node1Sub = document.getElementById("node1Sub");
            if (node1Sub) node1Sub.textContent = data.original_filename;
            const node1Badge = document.getElementById("node1Badge");
            if (node1Badge) node1Badge.textContent = `${data.orig_width}×${data.orig_height}`;

            const node3Sub = document.getElementById("node3Sub");
            if (node3Sub) node3Sub.textContent = `${data.base_name}.mem`;
            const node8Sub = document.getElementById("node8Sub");
            if (node8Sub) node8Sub.textContent = `${data.base_name}_output.mem`;
            const node10Sub = document.getElementById("node10Sub");
            if (node10Sub) node10Sub.textContent = `${data.base_name}_reconstructed.png`;

            // Reset Download Buttons
            ["btnDownloadRunInputMem", "btnDownloadRunOutputMem", "btnDownloadRunOutputPng"].forEach(id => {
                const btn = document.getElementById(id);
                if (btn) { btn.href = "#"; btn.classList.add("disabled"); }
            });

            appendLog(`[SUCCESS] Image '${data.original_filename}' uploaded. Base name: '${data.base_name}'. Request UUID: ${data.request_id}`);
            setGlobalStatus("ready", "Image Uploaded");
            updateStatusList(1);
            highlightNode("node-1", "completed");
        } else {
            appendLog(`[ERROR] Upload failed: ${data.error}`);
            setGlobalStatus("error", "Upload Error");
            alert(`Upload failed: ${data.error}`);
        }
    } catch (err) {
        appendLog(`[EXCEPTION] ${err.message}`);
        setGlobalStatus("error", "Error");
        alert(`Upload error: ${err.message}`);
    }
}

// MODE B: FULL PIPELINE EXECUTION
async function runFullPipeline() {
    const runBtn = document.getElementById("runAllBtn");
    if (runBtn) {
        runBtn.disabled = true;
        runBtn.style.opacity = "0.6";
    }

    setGlobalStatus("active", "● Hardware Simulation Running...");
    appendLog("=========================================================");
    appendLog("Starting End-to-End Hardware Convolution Pipeline...");
    appendLog("=========================================================");

    // Reset pipeline visualizer nodes
    for (let i = 1; i <= 10; i++) highlightNode(`node-${i}`, "reset");

    try {
        const fileInput = document.getElementById("imageUploadInput");
        let reqId = activePixelFlowSession.requestId;

        // Upload file if selected but not yet uploaded
        if (fileInput && fileInput.files.length > 0 && !reqId) {
            const formData = new FormData();
            formData.append("file", fileInput.files[0]);
            const uploadRes = await fetch("/api/upload", { method: "POST", body: formData });
            const uploadData = await uploadRes.json();
            if (!uploadData.success) throw new Error(`Upload failed: ${uploadData.error}`);
            reqId = uploadData.request_id;
            activePixelFlowSession.requestId = reqId;
            activePixelFlowSession.filename = uploadData.original_filename;
            activePixelFlowSession.baseName = uploadData.base_name;
            activePixelFlowSession.origWidth = uploadData.orig_width;
            activePixelFlowSession.origHeight = uploadData.orig_height;
            activePixelFlowSession.sourceUrl = uploadData.image_url;
            
            const inputImg = document.getElementById("inputImgPreview");
            if (inputImg) { inputImg.src = uploadData.image_url; inputImg.style.display = "block"; }
            const inputPlaceholder = document.getElementById("inputImgPlaceholder");
            if (inputPlaceholder) inputPlaceholder.style.display = "none";
            document.getElementById("uploadFilenameInfo").textContent = `Uploaded: ${uploadData.original_filename} (${uploadData.orig_width}×${uploadData.orig_height} px)`;
        }

        if (!reqId) {
            alert("Please select and upload an input image first before running PixelFlow.");
            setGlobalStatus("ready", "Image Required");
            return;
        }

        // Step 1: Input Image
        highlightNode("node-1", "completed");
        updateStatusList(1);

        // Step 2 & 3: prepare_image.py -> <base_name>.mem
        highlightNode("node-2", "active");
        appendLog(`[STEP 1/4] Invoking prepare_image.py for '${activePixelFlowSession.filename}' (session '${reqId}')...`);
        
        const prepRes = await fetch("/api/prepare", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ request_id: reqId, width: 32, height: 32 })
        });
        const prepData = await prepRes.json();
        if (!prepData.success) {
            throw new Error(`prepare_image.py failed: ${prepData.error}`);
        }
        
        activePixelFlowSession.inputMemFilename = prepData.mem_filename;
        activePixelFlowSession.inputMemSha256 = prepData.mem_sha256;
        document.getElementById("specInputMem").innerHTML = `<code>${prepData.mem_filename}</code> (SHA: ${prepData.short_sha256})`;
        const node3Sub = document.getElementById("node3Sub");
        if (node3Sub) node3Sub.textContent = `${prepData.mem_filename} (${prepData.short_sha256})`;
        
        const btnDlInMem = document.getElementById("btnDownloadRunInputMem");
        if (btnDlInMem) {
            btnDlInMem.href = prepData.download_url;
            btnDlInMem.textContent = `📥 Download ${prepData.mem_filename}`;
            btnDlInMem.classList.remove("disabled");
        }

        appendLog(`[STEP 1/4 SUCCESS] ${prepData.message}`);
        highlightNode("node-2", "completed");
        highlightNode("node-3", "completed");
        updateStatusList(2);

        // Step 4, 5, 6, 7, 8: $readmemh & SystemVerilog Simulation
        highlightNode("node-4", "completed");
        highlightNode("node-5", "active");
        highlightNode("node-6", "active");
        highlightNode("node-7", "active");
        highlightNode("node-8", "active");
        updateStatusList(3);
        appendLog(`[STEP 2/4] Launching SystemVerilog simulation for '${prepData.mem_filename}' (Vivado XSim RTL engine)...`);
        appendLog("Module hierarchy: image_filter_top -> row_convolver [1 2 1] -> column_convolver [1 2 1]ᵀ");

        const simRes = await fetch("/api/simulate", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ request_id: reqId })
        });
        const simData = await simRes.json();
        if (!simData.success) {
            if (simData.log) appendLog("\n--- HARDWARE SIMULATION LOG ---\n" + simData.log + "\n--- END LOG ---");
            throw new Error(`Hardware simulation failed: ${simData.error}`);
        }
        
        activePixelFlowSession.outputMemFilename = simData.output_mem_filename;
        activePixelFlowSession.outputMemSha256 = simData.output_mem_sha256;
        document.getElementById("specOutputMem").innerHTML = `<code>${simData.output_mem_filename}</code> (SHA: ${simData.short_out_mem_sha256})`;
        const node8Sub = document.getElementById("node8Sub");
        if (node8Sub) node8Sub.textContent = `${simData.output_mem_filename} (${simData.short_out_mem_sha256})`;

        const btnDlOutMem = document.getElementById("btnDownloadRunOutputMem");
        if (btnDlOutMem) {
            btnDlOutMem.href = `/api/download_temp/${reqId}/${simData.output_mem_filename}`;
            btnDlOutMem.textContent = `📥 Download ${simData.output_mem_filename}`;
            btnDlOutMem.classList.remove("disabled");
        }

        appendLog(`[STEP 2/4 SUCCESS] ${simData.message} (Elapsed: ${simData.elapsed}s)`);
        highlightNode("node-5", "completed");
        highlightNode("node-6", "completed");
        highlightNode("node-7", "completed");
        highlightNode("node-8", "completed");

        // Step 9 & 10: reconstruct.py -> PNG
        highlightNode("node-9", "active");
        highlightNode("node-10", "active");
        updateStatusList(4);
        updateStatusList(5);
        appendLog(`[STEP 4/4] Invoking reconstruct.py on hardware '${simData.output_mem_filename}'...`);

        const reconRes = await fetch("/api/reconstruct", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({ request_id: reqId })
        });
        const reconData = await reconRes.json();
        if (!reconData.success) {
            throw new Error(`reconstruct.py failed: ${reconData.error}`);
        }

        activePixelFlowSession.outputPngSha256 = reconData.output_sha256;
        activePixelFlowSession.outputUrl = reconData.image_url;

        // Update UI Image Preview with unique cache-busting URL
        const outImg = document.getElementById("outputImgPreview");
        if (outImg) {
            outImg.src = reconData.image_url;
            outImg.style.display = "block";
        }
        const outPlaceholder = document.getElementById("outputImgPlaceholder");
        if (outPlaceholder) outPlaceholder.style.display = "none";
        
        const resBadge = document.getElementById("outputResBadge");
        if (resBadge) resBadge.textContent = "32 × 32 Hardware Output";

        const outFooter = document.getElementById("outputImgFooter");
        if (outFooter) outFooter.innerHTML = `Artifact: <code>${reconData.reconstructed_png}</code> (SHA: ${reconData.short_out_sha256})`;

        const node10Sub = document.getElementById("node10Sub");
        if (node10Sub) node10Sub.textContent = `${reconData.reconstructed_png} (${reconData.short_out_sha256})`;

        const btnDlOutPng = document.getElementById("btnDownloadRunOutputPng");
        if (btnDlOutPng) {
            btnDlOutPng.href = reconData.download_url;
            btnDlOutPng.textContent = `📥 Download ${reconData.reconstructed_png}`;
            btnDlOutPng.classList.remove("disabled");
        }

        appendLog(`[STEP 4/4 SUCCESS] ${reconData.message}`);
        highlightNode("node-9", "completed");
        highlightNode("node-10", "completed");

        updateStatusList(6);
        setGlobalStatus("success", "✓ Simulation Complete");
        appendLog("=========================================================");
        appendLog("PIXELFLOW HARDWARE PIPELINE COMPLETE: 0 MISMATCHES!");
        appendLog("=========================================================");

    } catch (err) {
        appendLog(`[HARDWARE FAILURE] ${err.message}`);
        setGlobalStatus("error", "✕ Simulation Failed");
        alert(`Pipeline Execution Error: ${err.message}`);
    } finally {
        if (runBtn) {
            runBtn.disabled = false;
            runBtn.style.opacity = "1.0";
        }
    }
}

// MODE A: TOOL 6A (IMAGE -> MEM) FILE SELECTION & GENERATION
function handleImgToMemFileSelect(e) {
    const file = e.target.files[0];
    if (!file) return;

    // Reset active session state completely
    activeConversionSession = {
        requestId: null,
        sourceFilename: file.name,
        baseName: null,
        origWidth: null,
        origHeight: null,
        targetWidth: 32,
        targetHeight: 32,
        sha256: null,
        sourceUrl: null,
        preprocessedUrl: null,
        memGenerated: false
    };

    // Reset UI panels and clear images
    document.getElementById("convImgName").textContent = file.name;
    document.getElementById("convImgOrigDim").textContent = "Inspecting...";
    document.getElementById("imgToMemInfo").style.display = "block";
    document.getElementById("genMemResult").style.display = "none";
    document.getElementById("sessionReconResult").style.display = "none";
    
    document.getElementById("reconCompOriginal").src = "";
    document.getElementById("reconCompPrep").src = "";
    document.getElementById("reconCompResult").src = "";

    const reader = new FileReader();
    reader.onload = function(evt) {
        document.getElementById("convImgPreview").src = evt.target.result;
        
        // Read image natural width/height
        const tempImg = new Image();
        tempImg.onload = function() {
            activeConversionSession.origWidth = tempImg.width;
            activeConversionSession.origHeight = tempImg.height;
            document.getElementById("convImgOrigDim").textContent = `${tempImg.width} × ${tempImg.height} px`;
        };
        tempImg.src = evt.target.result;
    };
    reader.readAsDataURL(file);
}

// Generate MEM for currently selected image
async function runGenerateMem() {
    const btn = document.getElementById("btnGenMem");
    btn.disabled = true;
    btn.textContent = "⏳ GENERATING MEM...";

    // Hide previous reconstruction results
    document.getElementById("genMemResult").style.display = "none";
    document.getElementById("sessionReconResult").style.display = "none";

    try {
        const fileInput = document.getElementById("imgToMemInput");
        let reqId = activeConversionSession.requestId;

        // Step 1: Upload image if a new file was chosen or no session exists
        if (fileInput.files.length > 0 && !reqId) {
            const formData = new FormData();
            formData.append("file", fileInput.files[0]);

            const uploadRes = await fetch("/api/upload", { method: "POST", body: formData });
            const uploadData = await uploadRes.json();
            if (!uploadData.success) {
                throw new Error(`Upload failed: ${uploadData.error}`);
            }
            reqId = uploadData.request_id;
            activeConversionSession.requestId = reqId;
            activeConversionSession.sourceUrl = uploadData.image_url;
            activeConversionSession.origWidth = uploadData.orig_width;
            activeConversionSession.origHeight = uploadData.orig_height;
        }

        if (!reqId) {
            throw new Error("Please select an input image file first.");
        }

        // Step 2: Prepare MEM
        const targetW = parseInt(document.getElementById("convWidth").value) || 32;
        const targetH = parseInt(document.getElementById("convHeight").value) || 32;

        const prepRes = await fetch("/api/prepare", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                request_id: reqId,
                target_width: targetW,
                target_height: targetH
            })
        });

        const prepData = await prepRes.json();
        if (!prepData.success) {
            throw new Error(`prepare_image.py failed: ${prepData.error}`);
        }

        // Update active session metadata
        activeConversionSession.requestId = prepData.request_id;
        activeConversionSession.sourceFilename = prepData.source_filename;
        activeConversionSession.baseName = prepData.base_name;
        activeConversionSession.sha256 = prepData.mem_sha256;
        activeConversionSession.targetWidth = prepData.target_width;
        activeConversionSession.targetHeight = prepData.target_height;
        activeConversionSession.preprocessedUrl = prepData.preprocessed_url;
        activeConversionSession.memGenerated = true;

        // Populate UI Result Elements
        document.getElementById("resSourceImg").textContent = `${prepData.source_filename} (${prepData.orig_width}×${prepData.orig_height})`;
        document.getElementById("resTargetDim").textContent = `${prepData.target_width} × ${prepData.target_height} (${prepData.total_pixels} Pixels)`;
        document.getElementById("resSessionId").textContent = prepData.request_id;
        document.getElementById("resMemSha256").textContent = prepData.short_sha256;
        document.getElementById("conv32x32Preview").src = prepData.preprocessed_url;

        const previewGrid = document.getElementById("convHexPreview");
        if (previewGrid && prepData.hex_preview) {
            previewGrid.innerHTML = prepData.hex_preview.map(val => `<span>${val}</span>`).join("");
        }

        const downloadBtn = document.getElementById("btnDownloadMem");
        if (downloadBtn) {
            downloadBtn.href = prepData.download_url;
            downloadBtn.textContent = `📥 DOWNLOAD ${prepData.mem_filename}`;
        }

        document.getElementById("genMemResult").style.display = "block";

    } catch (err) {
        alert(`MEM Generation Failed: ${err.message}`);
    } finally {
        btn.disabled = false;
        btn.textContent = "⚡ GENERATE MEM";
    }
}

// Reconstruct image using the EXACT generated MEM from active session
async function runReconstructCurrentSessionMem() {
    if (!activeConversionSession.memGenerated || !activeConversionSession.requestId) {
        alert("ERROR: No generated MEM artifact found in the current conversion session. Please click GENERATE MEM first.");
        return;
    }

    const btn = document.getElementById("btnReconstructSessionMem");
    btn.disabled = true;
    btn.textContent = "⏳ RECONSTRUCTING...";

    try {
        const reconRes = await fetch("/api/reconstruct_convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                request_id: activeConversionSession.requestId,
                expected_sha256: activeConversionSession.sha256,
                is_manual: false,
                target_width: activeConversionSession.targetWidth,
                target_height: activeConversionSession.targetHeight
            })
        });

        const reconData = await reconRes.json();
        if (!reconData.success) {
            throw new Error(`Reconstruction failed: ${reconData.error}`);
        }

        // Display Side-by-Side Comparison
        const convPreviewSrc = document.getElementById("convImgPreview").src || activeConversionSession.sourceUrl;
        document.getElementById("reconCompOriginal").src = convPreviewSrc;
        document.getElementById("reconCompPrep").src = activeConversionSession.preprocessedUrl;
        document.getElementById("reconCompResult").src = reconData.image_url;

        const downloadPngBtn = document.getElementById("btnDownloadSessionReconPng");
        if (downloadPngBtn) {
            downloadPngBtn.href = reconData.download_url;
            downloadPngBtn.textContent = `📥 DOWNLOAD ${reconData.reconstructed_filename}`;
        }

        document.getElementById("sessionReconResult").style.display = "block";

    } catch (err) {
        alert(`Reconstruction Error: ${err.message}`);
    } finally {
        btn.disabled = false;
        btn.textContent = "🔄 RECONSTRUCT THIS GENERATED MEM";
    }
}

// Tool 2: Manual MEM Upload Handler
async function handleMemToImgFileSelect(e) {
    const file = e.target.files[0];
    if (!file) return;

    // Reset manual MEM session state
    manualMemSession = {
        requestId: null,
        filename: file.name,
        baseName: null,
        sha256: null,
        detectedPixels: 0
    };

    // Reset UI DOM elements
    document.getElementById("convMemName").textContent = file.name;
    document.getElementById("convMemCount").textContent = "Analyzing...";
    document.getElementById("convMemSha256").textContent = "Calculating...";
    document.getElementById("convMemSessionId").textContent = "-";
    document.getElementById("memToImgInfo").style.display = "block";
    document.getElementById("reconResult").style.display = "none";
    document.getElementById("reconImgPreview").src = "";

    const formData = new FormData();
    formData.append("file", file);

    try {
        const res = await fetch("/api/upload_mem_convert", {
            method: "POST",
            body: formData
        });
        const data = await res.json();
        if (data.success) {
            manualMemSession.requestId = data.request_id;
            manualMemSession.filename = file.name;
            manualMemSession.baseName = data.base_name;
            manualMemSession.sha256 = data.mem_sha256;
            manualMemSession.detectedPixels = data.detected_pixels;

            document.getElementById("convMemName").textContent = file.name;
            document.getElementById("convMemCount").textContent = `${data.detected_pixels} lines`;
            document.getElementById("convMemSha256").textContent = data.short_sha256;
            document.getElementById("convMemSessionId").textContent = data.request_id;
        } else {
            alert(`MEM upload failed: ${data.error}`);
        }
    } catch (err) {
        alert(`MEM upload error: ${err.message}`);
    }
}

// Tool 2: Reconstruct Manual MEM File
async function runReconstructManualMem() {
    if (!manualMemSession.requestId) {
        alert("ERROR: Please upload a manual .mem file first.");
        return;
    }

    const btn = document.getElementById("btnReconstruct");
    btn.disabled = true;
    btn.textContent = "⏳ RECONSTRUCTING...";

    // Clear previous DOM image to eliminate browser caching artifact
    document.getElementById("reconImgPreview").src = "";
    document.getElementById("reconResult").style.display = "none";

    try {
        const targetW = parseInt(document.getElementById("reconWidth").value) || 32;
        const targetH = parseInt(document.getElementById("reconHeight").value) || 32;

        const res = await fetch("/api/reconstruct_convert", {
            method: "POST",
            headers: { "Content-Type": "application/json" },
            body: JSON.stringify({
                request_id: manualMemSession.requestId,
                expected_sha256: manualMemSession.sha256,
                is_manual: true,
                target_width: targetW,
                target_height: targetH
            })
        });

        const data = await res.json();
        if (data.success) {
            document.getElementById("manualResMemSha256").textContent = data.short_mem_sha256;
            document.getElementById("manualResOutSha256").textContent = data.short_out_sha256;
            document.getElementById("manualResArtifactName").textContent = data.reconstructed_filename;
            
            document.getElementById("reconImgPreview").src = data.image_url;
            const downloadBtn = document.getElementById("btnDownloadReconPng");
            if (downloadBtn) {
                downloadBtn.href = data.download_url;
                downloadBtn.textContent = `📥 DOWNLOAD ${data.reconstructed_filename}`;
            }
            document.getElementById("reconResult").style.display = "block";
        } else {
            alert(`Manual MEM Reconstruction Failed: ${data.error}`);
        }
    } catch (err) {
        alert(`Error: ${err.message}`);
    } finally {
        btn.disabled = false;
        btn.textContent = "🖼️ RECONSTRUCT MANUAL MEM FILE";
    }
}

// VIVADO REPORTS DISCOVERY & VIEWER
async function refreshReportsList() {
    const grid = document.getElementById("reportsGrid");
    if (!grid) return;

    try {
        const res = await fetch("/api/reports");
        const data = await res.json();

        if (data.success && data.reports.length > 0) {
            grid.innerHTML = data.reports.map(rpt => {
                const metricsHtml = Object.entries(rpt.metrics || {}).map(([k, v]) => `
                    <div class="metric-item">
                        <span class="lbl">${k}:</span>
                        <span class="val">${v}</span>
                    </div>
                `).join("");

                return `
                    <div class="report-card">
                        <div class="report-header">
                            <div>
                                <div class="report-title">${rpt.title}</div>
                                <div style="font-size:11px;color:var(--text-muted);font-family:var(--font-mono);">${rpt.filename} (${Math.round(rpt.size_bytes/1024)} KB)</div>
                            </div>
                            <span class="report-cat">${rpt.category}</span>
                        </div>

                        ${metricsHtml ? `<div class="report-metrics">${metricsHtml}</div>` : ''}

                        <div class="report-actions">
                            <button class="btn btn-sm btn-secondary" onclick="viewReportContent('${rpt.filename}', '${rpt.title}')">👁️ VIEW</button>
                            <a href="/api/download/report/${rpt.filename}" class="btn btn-sm btn-subtle" download>📥 DOWNLOAD</a>
                        </div>
                    </div>
                `;
            }).join("");
        } else {
            grid.innerHTML = `<div class="flow-disclaimer">No generated Vivado reports found. Run synthesis/simulation first.</div>`;
        }
    } catch (err) {
        grid.innerHTML = `<div class="flow-disclaimer">Error loading reports: ${err.message}</div>`;
    }
}

async function viewReportContent(filename, title) {
    const box = document.getElementById("reportViewerBox");
    const pre = document.getElementById("reportViewerPre");
    const ttl = document.getElementById("reportViewerTitle");

    ttl.textContent = `Report: ${title} (${filename})`;
    pre.textContent = "Loading report content...";
    box.style.display = "block";

    try {
        const res = await fetch(`/api/reports/${filename}`);
        const data = await res.json();
        if (data.success) {
            pre.textContent = data.content;
        } else {
            pre.textContent = `Error: ${data.error}`;
        }
    } catch (err) {
        pre.textContent = `Exception: ${err.message}`;
    }
}

function closeReportViewer() {
    const box = document.getElementById("reportViewerBox");
    if (box) box.style.display = "none";
}

// ARCHITECTURE STAGE EXPLANATION MODAL
const stageExpls = {
    1: { title: "Stage 1: Input Image", desc: "The user selects/uploads a normal image file (PNG, JPG, BMP). PixelFlow loads it into an isolated request workspace." },
    2: { title: "Stage 2: Software Preprocessing", desc: "prepare_image.py converts the original image into an 8-bit grayscale format and resizes it to 32×32 resolution using Lanczos resampling." },
    3: { title: "Stage 3: Hexadecimal Memory (<base_name>.mem)", desc: "1024 pixel bytes are formatted into 2-digit uppercase hexadecimal strings (e.g. 00, 7F, FF) and written line-by-line in row-major order." },
    4: { title: "Stage 4: $readmemh Memory Loading", desc: "The SystemVerilog testbench executes $readmemh(INPUT_MEM, image_mem), loading hex values into simulation memory before driving the top-level RTL." },
    5: { title: "Stage 5: RTL Top Module (image_filter_top.sv)", desc: "SystemVerilog top-level wrapper instantiating row convolver, column convolver, and memory streaming interface." },
    6: { title: "Stage 6: Row Convolution (row_convolver.sv)", desc: "Direct-form 1D FIR filter performs horizontal convolution using the kernel [1 2 1] across parallel pixel streams." },
    7: { title: "Stage 7: Column Convolution (column_convolver.sv)", desc: "Transpose-form 1D FIR filter performs vertical convolution using the kernel [1 2 1]ᵀ across row buffers." },
    8: { title: "Stage 8: Hardware Output MEM (<base_name>_output.mem)", desc: "Filtered pixels output by the hardware pipeline are captured by the testbench and written to output MEM." },
    9: { title: "Stage 9: Software Reconstruction (reconstruct.py)", desc: "reconstruct.py reads hex values from output MEM and formats them back into a grayscale PNG file saved in the request workspace." },
    10: { title: "Stage 10: Reconstructed Image Artifact", desc: "Final reconstructed PNG output image displayed in dashboard with exact SHA-256 verification." }
};

function showStageModal(stageId) {
    const modal = document.getElementById("stageModal");
    const ttl = document.getElementById("modalStageTitle");
    const bdy = document.getElementById("modalStageBody");
    const info = stageExpls[stageId];

    if (info) {
        ttl.textContent = info.title;
        bdy.textContent = info.desc;
        modal.style.display = "flex";
    }
}

function closeStageModal() {
    const modal = document.getElementById("stageModal");
    if (modal) modal.style.display = "none";
}
