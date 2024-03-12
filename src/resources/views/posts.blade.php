<!DOCTYPE html>
<html lang="en">

<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <meta http-equiv="X-UA-Compatible" content="ie=edge">
    <title>Posts Tailwind</title>
    <link rel="stylesheet" href="{{ mix('css/app.css') }}">
    {{-- @vite(['resources/css/app.css', 'resources/js/app.js']) --}}
</head>

<body>
    <div class="container mx-auto">
        <div class="grid grid-cols-3 gap-4">
            @foreach ($posts as $post)
                <div class="post">
                    <h3 class="text-xl">{{ $post->title }}</h3>
                    <p class="font-light">{{ $post->content }}</p>
                </div>
            @endforeach
        </div>
    </div>
</body>

</html>
