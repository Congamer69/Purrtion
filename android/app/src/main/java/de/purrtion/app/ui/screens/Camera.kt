package de.purrtion.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.graphics.Matrix
import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.camera.core.CameraSelector
import androidx.camera.core.ImageAnalysis
import androidx.camera.core.Preview
import androidx.camera.lifecycle.ProcessCameraProvider
import androidx.camera.view.PreviewView
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowForward
import androidx.compose.material.icons.rounded.AddCircle
import androidx.compose.material.icons.rounded.AutoAwesome
import androidx.compose.material.icons.rounded.CameraAlt
import androidx.compose.material.icons.rounded.FlashOff
import androidx.compose.material.icons.rounded.FlashOn
import androidx.compose.material.icons.rounded.Image
import androidx.compose.material.icons.rounded.Pets
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Remove
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.CheckCircle
import androidx.compose.material.icons.rounded.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalLifecycleOwner
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.viewinterop.AndroidView
import androidx.core.content.ContextCompat
import androidx.core.content.FileProvider
import androidx.exifinterface.media.ExifInterface
import com.google.mlkit.vision.barcode.BarcodeScanning
import com.google.mlkit.vision.barcode.BarcodeScannerOptions
import com.google.mlkit.vision.barcode.common.Barcode
import com.google.mlkit.vision.common.InputImage
import de.purrtion.app.data.FoodEntry
import de.purrtion.app.data.Store
import de.purrtion.app.domain.AITask
import de.purrtion.app.domain.MealVision
import de.purrtion.app.domain.OpenFoodFacts
import de.purrtion.app.model.FoodItem
import de.purrtion.app.model.FoodSource
import de.purrtion.app.model.Nutrients
import de.purrtion.app.model.RecipeIngredient
import de.purrtion.app.model.ServingOption
import de.purrtion.app.model.clean
import de.purrtion.app.model.kcalString
import de.purrtion.app.ui.MacroDot
import de.purrtion.app.ui.Nav
import de.purrtion.app.ui.NumberInput
import de.purrtion.app.ui.PillButton
import de.purrtion.app.ui.Screen
import de.purrtion.app.ui.TextInput
import de.purrtion.app.ui.card
import de.purrtion.app.ui.rememberHaptics
import de.purrtion.app.ui.squishClick
import de.purrtion.app.ui.pixel.CatMascot
import de.purrtion.app.ui.pixel.CatMood
import de.purrtion.app.ui.pixel.PixelSpriteView
import de.purrtion.app.ui.pixel.Sprites
import de.purrtion.app.ui.pixel.WalkingCatLoader
import de.purrtion.app.ui.theme.C
import de.purrtion.app.ui.theme.Palette
import de.purrtion.app.ui.theme.Radius
import de.purrtion.app.ui.theme.font
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.io.File
import java.time.LocalDate
import java.util.UUID
import java.util.concurrent.Executors
import kotlin.math.max
import kotlin.math.min

@Composable
private fun rememberCameraPermission(): Pair<Boolean, () -> Unit> {
    val context = LocalContext.current
    var granted by remember { mutableStateOf(ContextCompat.checkSelfPermission(context, Manifest.permission.CAMERA) == PackageManager.PERMISSION_GRANTED) }
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }
    return granted to { launcher.launch(Manifest.permission.CAMERA) }
}

// MARK: Barcode

/** Scan → look up in Open Food Facts → choose amount → log. */
@Composable
fun BarcodeSheet(day: LocalDate, back: Boolean = false,
                 /** Set when scanning for a recipe or meal: the product is picked with its amount instead of being logged. */
                 onPick: ((FoodItem, Double, ServingOption) -> Unit)? = null) {
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    val (granted, request) = rememberCameraPermission()
    var torch by remember { mutableStateOf(false) }
    var manual by remember { mutableStateOf("") }
    var state by remember { mutableStateOf<String?>(null) }          // null scanning, "loading:<code>", "notfound:<code>", "failed"
    var lastCode by remember { mutableStateOf<String?>(null) }
    var showingDetail by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { if (!granted) request() }

    fun lookup(raw: String) {
        val code = raw.filter(Char::isDigit)
        if (code.length < 6 || code == lastCode || showingDetail || state?.startsWith("loading") == true) return
        lastCode = code
        h.tap()
        state = "loading:$code"
        scope.launch {
            try {
                val food = OpenFoodFacts.product(code)
                if (food != null) {
                    h.success(); state = null; showingDetail = true
                    Nav.push {
                        if (onPick != null) FoodDetailScreen(food, DetailMode.Pick { f, q, s -> Nav.dismissSheet(); onPick(f, q, s) })
                        else FoodDetailScreen(food, DetailMode.Add(day)) { Nav.dismissSheet() }
                    }
                } else { h.warning(); state = "notfound:$code" }
            } catch (e: Exception) {
                state = "failed"
            }
        }
    }

    Screen("Barcode scannen", back = back, leading = if (back) null else "Schließen", trailing = {
        IconButton(onClick = { torch = !torch }, enabled = granted) {
            Icon(if (torch) Icons.Rounded.FlashOn else Icons.Rounded.FlashOff, if (torch) "Blitz ausschalten" else "Blitz einschalten", tint = Palette.accent)
        }
    }) {
        Box(Modifier.fillMaxWidth().height(300.dp).clip(RoundedCornerShape(Radius)).background(Color.Black)) {
            if (granted) {
                // The torch only burns while looking for a code – off as soon as one was recognised.
                BarcodeCamera(torch && state == null && !showingDetail) { lookup(it) }
                ScannerFrame()
            } else {
                Column(Modifier.fillMaxSize().background(C.card), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.Center) {
                    CatMascot(CatMood.sleeping, 5.dp)
                    Spacer(Modifier.height(12.dp))
                    Text("Kamera-Zugriff fehlt", style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                    Text("Erlaube die Kamera oder gib den Barcode unten ein.", style = font(14), color = C.textSecondary)
                    Spacer(Modifier.height(10.dp))
                    PillButton("Kamera erlauben", Modifier.padding(horizontal = 40.dp), filled = false) { request() }
                }
            }
        }
        val s = state
        when {
            s == null -> Text(if (granted) "Halte den Barcode in den Rahmen" else "", style = font(15, FontWeight.Medium), color = C.textSecondary,
                modifier = Modifier.fillMaxWidth(), textAlign = TextAlign.Center)
            s.startsWith("loading") -> Box(Modifier.fillMaxWidth(), contentAlignment = Alignment.Center) { WalkingCatLoader(2.5.dp, 200.dp, "Suche Produkt …") }
            s.startsWith("notfound") -> Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                PixelSpriteView(Sprites.fish, 3.dp)
                Text("Produkt ${s.substringAfter(":")} nicht gefunden", style = font(15, FontWeight.SemiBold), color = C.textPrimary)
                Text("Du kannst es über ⚡ Schnell-Eintrag manuell erfassen.", style = font(13), color = C.textSecondary)
                Text("Nochmal scannen", style = font(15, FontWeight.SemiBold), color = Palette.accent,
                    modifier = Modifier.padding(8.dp).squishClick { state = null; lastCode = null })
            }
            else -> Column(Modifier.fillMaxWidth(), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Keine Verbindung zu Open Food Facts.", style = font(14), color = Palette.danger)
                Text("Nochmal versuchen", style = font(15, FontWeight.SemiBold), color = Palette.accent,
                    modifier = Modifier.padding(8.dp).squishClick { state = null; lastCode = null })
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp), verticalAlignment = Alignment.CenterVertically) {
            NumberInput(manual, { manual = it }, Modifier.weight(1f).height(50.dp).clip(RoundedCornerShape(16.dp)).background(C.card).padding(horizontal = 16.dp),
                "Barcode eingeben", style = font(17), align = TextAlign.Start, decimal = false)
            Box(Modifier.size(50.dp).clip(RoundedCornerShape(16.dp)).background(Palette.accent.copy(alpha = if (manual.length >= 6) 1f else 0.4f))
                .squishClick(manual.length >= 6) { lookup(manual) }, contentAlignment = Alignment.Center) {
                Icon(Icons.AutoMirrored.Rounded.ArrowForward, "Suchen", tint = Color.White)
            }
        }
    }
    // Back from the detail screen: scan again.
    LaunchedEffect(Nav.stack.size) { if (showingDetail && Nav.stack.lastOrNull()?.sheet == true) { showingDetail = false; state = null; lastCode = null } }
}

@Composable
private fun BarcodeCamera(torch: Boolean, onCode: (String) -> Unit) {
    val context = LocalContext.current
    val owner = LocalLifecycleOwner.current
    val executor = remember { Executors.newSingleThreadExecutor() }
    var camera by remember { mutableStateOf<androidx.camera.core.Camera?>(null) }
    LaunchedEffect(torch, camera) { camera?.cameraControl?.enableTorch(torch) }
    AndroidView(factory = { ctx ->
        val view = PreviewView(ctx).apply { scaleType = PreviewView.ScaleType.FILL_CENTER }
        val providerFuture = ProcessCameraProvider.getInstance(ctx)
        providerFuture.addListener({
            val provider = providerFuture.get()
            val preview = Preview.Builder().build().also { it.surfaceProvider = view.surfaceProvider }
            val scanner = BarcodeScanning.getClient(BarcodeScannerOptions.Builder().setBarcodeFormats(
                Barcode.FORMAT_EAN_13, Barcode.FORMAT_EAN_8, Barcode.FORMAT_UPC_A, Barcode.FORMAT_UPC_E, Barcode.FORMAT_CODE_128).build())
            val analysis = ImageAnalysis.Builder().setBackpressureStrategy(ImageAnalysis.STRATEGY_KEEP_ONLY_LATEST).build()
            analysis.setAnalyzer(executor) { proxy ->
                val media = proxy.image
                if (media == null) { proxy.close(); return@setAnalyzer }
                scanner.process(InputImage.fromMediaImage(media, proxy.imageInfo.rotationDegrees))
                    .addOnSuccessListener { codes -> codes.firstNotNullOfOrNull { it.rawValue }?.let { v -> ContextCompat.getMainExecutor(ctx).execute { onCode(v) } } }
                    .addOnCompleteListener { proxy.close() }
            }
            runCatching {
                provider.unbindAll()
                camera = provider.bindToLifecycle(owner, CameraSelector.DEFAULT_BACK_CAMERA, preview, analysis)
            }
        }, ContextCompat.getMainExecutor(ctx))
        view
    }, modifier = Modifier.fillMaxSize())
    DisposableEffect(Unit) { onDispose { runCatching { ProcessCameraProvider.getInstance(context).get().unbindAll() }; executor.shutdown() } }
}

@Composable
private fun ScannerFrame() {
    val t = rememberInfiniteTransition(label = "scan")
    val p by t.animateFloat(0f, 1f, infiniteRepeatable(tween(1600), RepeatMode.Reverse), label = "line")
    Canvas(Modifier.fillMaxSize()) {
        val w = size.width * 0.75f
        val hgt = 130.dp.toPx()
        val left = (size.width - w) / 2
        val top = (size.height - hgt) / 2
        drawRoundRect(Color.White.copy(alpha = 0.9f), Offset(left, top), Size(w, hgt), CornerRadius(18.dp.toPx()),
            style = Stroke(4.dp.toPx(), pathEffect = PathEffect.dashPathEffect(floatArrayOf(14.dp.toPx(), 10.dp.toPx()))))
        drawRect(Palette.accent, Offset(left + 12.dp.toPx(), top + 12.dp.toPx() + (hgt - 24.dp.toPx()) * p), Size(w - 24.dp.toPx(), 3.dp.toPx()))
    }
}

// MARK: Meal photo / AI estimate

private class EditableItem(
    val id: String = UUID.randomUUID().toString(),
    recognized: String, food: FoodItem, grams: Double, val confidence: String, isAI: Boolean, val fromDatabase: Boolean = false,
) {
    var recognized by mutableStateOf(recognized)
    var food by mutableStateOf(food)
    var grams by mutableStateOf(min(max(0.0, grams), 5000.0))
    var include by mutableStateOf(true)
    var isAI by mutableStateOf(isAI)
    /** Fixed upper end of the slider – chosen once, so dragging can never grow the range. */
    var sliderMax by mutableStateOf(min(5000.0, max(600.0, Math.ceil(grams * 2.5 / 50) * 50)))
}

/** Photo of a meal (or a description) → AI estimates components and nutrients → adjust or replace → log. */
@Composable
fun MealPhotoSheet(day: LocalDate, textQuery: String? = null, back: Boolean = false, onLogged: ((String) -> Unit)? = null) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val h = rememberHaptics()
    var image by remember { mutableStateOf<Bitmap?>(null) }
    var hint by remember { mutableStateOf("") }
    var phase by remember { mutableStateOf(if (textQuery != null) "analyzing" else "idle") }   // idle, analyzing, result, failed
    var error by remember { mutableStateOf("") }
    var dish by remember { mutableStateOf("") }
    val items = remember { mutableStateListOf<EditableItem>() }
    val photoFile = remember { File(context.cacheDir, "meal-photo.jpg") }
    val photoUri = remember { FileProvider.getUriForFile(context, "${context.packageName}.files", photoFile) }

    fun analyze() {
        phase = "analyzing"
        scope.launch {
            try {
                val result = if (textQuery != null) MealVision.analyze(textQuery) else MealVision.analyze(image!!, hint)
                dish = result.dish
                items.clear()
                items.addAll(result.items.map { EditableItem(recognized = it.name, food = it.food, grams = Math.round(it.grams).toDouble(), confidence = it.confidence, isAI = it.isAIEstimate) })
                h.success(); phase = "result"
            } catch (e: Exception) {
                h.warning(); error = e.message ?: "Analyse fehlgeschlagen"; phase = "failed"
            }
        }
    }
    LaunchedEffect(Unit) { if (textQuery != null) analyze() }

    val takePhoto = rememberLauncherForActivityResult(ActivityResultContracts.TakePicture()) { ok ->
        if (ok) scope.launch { image = withContext(Dispatchers.IO) { loadBitmap(context, photoUri) }; if (image != null) analyze() }
    }
    val pick = rememberLauncherForActivityResult(ActivityResultContracts.PickVisualMedia()) { uri: Uri? ->
        if (uri != null) scope.launch { image = withContext(Dispatchers.IO) { loadBitmap(context, uri) }; if (image != null) analyze() }
    }

    val selected = items.filter { it.include }
    val total = Nutrients.sum(selected.map { it.food.nutrients(it.grams) })

    Screen(if (textQuery == null) "Gericht scannen" else "KI-Schätzung", back = back, leading = if (back) null else "Schließen",
        bottom = if (phase == "result") ({
            PillButton(if (selected.size == 1) "Eintragen · ${total.kcal.kcalString} kcal" else "${selected.size} Einträge · ${total.kcal.kcalString} kcal",
                icon = Icons.Rounded.Pets, enabled = selected.isNotEmpty()) {
                scope.launch {
                    val name = dish.trim().ifEmpty { "KI-Mahlzeit" }
                    if (selected.size == 1) {
                        // A single dish is logged like any other food and keeps its estimated portion for next time.
                        val only = selected[0]
                        val food = only.food.copy(servings = listOf(ServingOption("1 Portion", only.grams)))
                        Store.log(food, only.grams, ServingOption.base(food.unit), day)
                    } else {
                        Store.insert(FoodEntry.meal(name, selected.map { RecipeIngredient(food = it.food, quantity = it.grams, serving = ServingOption.base(it.food.unit)) }, FoodSource.ai, day))
                    }
                    h.success()
                    val label = if (selected.size == 1) selected[0].food.displayName else name
                    if (onLogged != null) onLogged(label) else Nav.pop()
                }
            }
        }) else null) {
        if (textQuery != null) {
            Row(Modifier.fillMaxWidth().card(14.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(44.dp).clip(CircleShape).background(C.accentSoft), contentAlignment = Alignment.Center) {
                    Icon(Icons.Rounded.AutoAwesome, null, tint = Palette.accent)
                }
                Spacer(Modifier.width(12.dp))
                Column {
                    Text("„$textQuery“", style = font(17, FontWeight.SemiBold), color = C.textPrimary)
                    Text("Schätzung mit ${AITask.photo.provider.title}", style = font(12), color = C.textSecondary)
                }
            }
        } else {
            Box(Modifier.fillMaxWidth().height(240.dp).clip(RoundedCornerShape(Radius)).background(C.card), contentAlignment = Alignment.Center) {
                val img = image
                if (img != null) Image(img.asImageBitmap(), null, Modifier.fillMaxSize(), contentScale = ContentScale.Crop)
                else Column(Modifier.padding(20.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                    Row(verticalAlignment = Alignment.Bottom) { CatMascot(CatMood.idle, 4.dp); Spacer(Modifier.width(10.dp)); PixelSpriteView(Sprites.bowl, 4.dp) }
                    Spacer(Modifier.height(14.dp))
                    Text("Fotografiere dein Essen. Ich erkenne die Bestandteile und schätze Mengen und Nährwerte.", style = font(14), color = C.textSecondary, textAlign = TextAlign.Center)
                }
            }
        }
        when (phase) {
            "idle" -> {
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    PillButton("Kamera", Modifier.weight(1f), icon = Icons.Rounded.CameraAlt) { takePhoto.launch(photoUri) }
                    PillButton("Foto wählen", Modifier.weight(1f), icon = Icons.Rounded.Image, filled = false) {
                        pick.launch(PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly))
                    }
                }
                TextInput(hint, { hint = it }, "Optional: Hinweis, z. B. „mit Sahnesoße“",
                    Modifier.fillMaxWidth().height(48.dp).clip(RoundedCornerShape(14.dp)).background(C.card).padding(horizontal = 16.dp), style = font(15))
            }
            "analyzing" -> Box(Modifier.fillMaxWidth().padding(vertical = 20.dp), contentAlignment = Alignment.Center) {
                WalkingCatLoader(3.dp, 220.dp, "Deine Katze schnuppert am Essen …")
            }
            "failed" -> Column(Modifier.fillMaxWidth().card(), horizontalAlignment = Alignment.CenterHorizontally, verticalArrangement = Arrangement.spacedBy(10.dp)) {
                CatMascot(CatMood.full, 4.dp)
                Text(error, style = font(15), color = C.textPrimary, textAlign = TextAlign.Center)
                PillButton("Nochmal versuchen", filled = false) { analyze() }
            }
            "result" -> {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(dish, style = font(20, FontWeight.Bold), color = C.textPrimary)
                        Text("${total.kcal.kcalString} kcal · Mengen geschätzt", style = font(13), color = C.textSecondary)
                        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { MacroDot(Palette.protein, total.protein); MacroDot(Palette.carbs, total.carbs); MacroDot(Palette.fat, total.fat) }
                    }
                    CatMascot(CatMood.happy, 3.dp)
                }
                for (item in items) ItemEditor(item) {
                    Nav.push { FoodReplacementPicker { food -> item.recognized = food.displayName; item.food = food; item.isAI = false; item.include = true; h.success() } }
                }
                PillButton("Zutat hinzufügen", icon = Icons.Rounded.AddCircle, filled = false) {
                    Nav.sheet { IngredientPickerSheet { food, q, s -> items += EditableItem(recognized = food.displayName, food = food, grams = q * s.grams, confidence = "Datenbank", isAI = false, fromDatabase = true) } }
                }
                Text("Die KI-Nährwerte sind Schätzungen. Über „Ersetzen durch“ kannst du jeden Eintrag aus den Lebensmitteldatenbanken auswählen; die Menge bleibt erhalten.",
                    style = font(12), color = C.textSecondary)
                if (textQuery == null) Row(Modifier.squishClick { phase = "idle"; image = null; items.clear() }, verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Rounded.Refresh, null, tint = Palette.accent)
                    Spacer(Modifier.width(6.dp))
                    Text("Neues Foto", style = font(15, FontWeight.SemiBold), color = Palette.accent)
                }
            }
        }
    }
}

@Composable
private fun ItemEditor(item: EditableItem, onReplace: () -> Unit) {
    val n = item.food.nutrients(item.grams)
    Column(Modifier.fillMaxWidth().alpha(if (item.include) 1f else 0.5f).card(14.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
        Row(verticalAlignment = Alignment.Top) {
            Icon(if (item.include) Icons.Rounded.CheckCircle else Icons.Rounded.RadioButtonUnchecked, null,
                Modifier.size(24.dp).squishClick { item.include = !item.include }, tint = if (item.include) Palette.accent else C.textSecondary)
            Spacer(Modifier.width(8.dp))
            Column(Modifier.weight(1f)) {
                Text(item.recognized, style = font(16, FontWeight.SemiBold), color = C.textPrimary)
                Text(if (item.isAI) "KI-Schätzung · ${item.food.per100.kcal.kcalString} kcal / 100 ${item.food.unit}"
                    else "${item.food.source.label} · ${item.food.per100.kcal.kcalString} kcal / 100 ${item.food.unit}",
                    style = font(12, FontWeight.Medium), color = Palette.accent, maxLines = 1)
                Text("Sicherheit: ${item.confidence}", style = font(11), color = C.textSecondary)
            }
            Text("${n.kcal.kcalString} kcal", style = font(16, FontWeight.Bold), color = C.textPrimary)
        }
        if (item.fromDatabase) {
            Text("${item.grams.clean} ${item.food.unit} · über Lebensmittelsuche hinzugefügt", style = font(13, FontWeight.Medium), color = C.textSecondary)
        } else {
            Row(Modifier.squishClick(onClick = onReplace), verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Search, null, Modifier.size(15.dp), tint = Palette.accent)
                Spacer(Modifier.width(4.dp))
                Text("Ersetzen durch", style = font(13, FontWeight.SemiBold), color = Palette.accent)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                Icon(Icons.Rounded.Remove, "Weniger", Modifier.squishClick { item.grams = max(0.0, item.grams - 10) }, tint = Palette.accent)
                Slider(min(item.grams, item.sliderMax).toFloat(), { item.grams = Math.round(it / 5.0) * 5.0 }, Modifier.weight(1f).padding(horizontal = 6.dp),
                    valueRange = 0f..max(item.sliderMax, 10.0).toFloat(),
                    colors = SliderDefaults.colors(thumbColor = Color.White, activeTrackColor = Palette.accent, inactiveTrackColor = C.cardAlt))
                Icon(Icons.Rounded.Add, "Mehr", Modifier.squishClick {
                    item.grams = min(item.grams + 10, 5000.0)
                    if (item.grams > item.sliderMax) item.sliderMax = min(5000.0, item.sliderMax * 2)
                }, tint = Palette.accent)
                Text("${item.grams.clean} ${item.food.unit}", style = font(14, FontWeight.SemiBold), color = C.textPrimary,
                    modifier = Modifier.width(70.dp), textAlign = TextAlign.End)
            }
        }
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) { MacroDot(Palette.protein, n.protein); MacroDot(Palette.carbs, n.carbs); MacroDot(Palette.fat, n.fat) }
    }
}

/** Loads a photo downscaled and upright (EXIF rotation applied). */
private fun loadBitmap(context: android.content.Context, uri: Uri): Bitmap? = runCatching {
    val opts = BitmapFactory.Options().apply { inJustDecodeBounds = true }
    context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, opts) }
    var sample = 1
    while (max(opts.outWidth, opts.outHeight) / sample > 2048) sample *= 2
    val bmp = context.contentResolver.openInputStream(uri)?.use { BitmapFactory.decodeStream(it, null, BitmapFactory.Options().apply { inSampleSize = sample }) }
        ?: return null
    val rotation = context.contentResolver.openInputStream(uri)?.use {
        when (ExifInterface(it).getAttributeInt(ExifInterface.TAG_ORIENTATION, ExifInterface.ORIENTATION_NORMAL)) {
            ExifInterface.ORIENTATION_ROTATE_90 -> 90f
            ExifInterface.ORIENTATION_ROTATE_180 -> 180f
            ExifInterface.ORIENTATION_ROTATE_270 -> 270f
            else -> 0f
        }
    } ?: 0f
    if (rotation == 0f) bmp else Bitmap.createBitmap(bmp, 0, 0, bmp.width, bmp.height, Matrix().apply { postRotate(rotation) }, true)
}.getOrNull()

